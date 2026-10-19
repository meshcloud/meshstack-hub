data "opentelekomcloud_identity_role_v3" "domain" {
  for_each = toset(var.domain_roles)

  name = each.value
}

data "opentelekomcloud_identity_role_v3" "project" {
  for_each = toset(var.project_roles)

  name = each.value
}

# T Cloud Public's Terraform provider cannot exchange an OIDC token, so the building blocks need a
# static credential.
resource "opentelekomcloud_identity_user_v3" "building_block" {
  name        = var.user_name
  description = "meshStack: creates T Cloud Public projects and maps project users into them."
  access_type = "programmatic"
}

resource "opentelekomcloud_identity_credential_v3" "building_block" {
  user_id     = opentelekomcloud_identity_user_v3.building_block.id
  description = "meshStack building blocks"
}

resource "opentelekomcloud_identity_group_v3" "building_block" {
  name        = var.user_name
  description = "Roles of the meshStack building block user."
}

resource "opentelekomcloud_identity_user_group_membership_v3" "building_block" {
  user   = opentelekomcloud_identity_user_v3.building_block.id
  groups = [opentelekomcloud_identity_group_v3.building_block.id]
}

resource "opentelekomcloud_identity_role_assignment_v3" "domain" {
  for_each = data.opentelekomcloud_identity_role_v3.domain

  group_id  = opentelekomcloud_identity_group_v3.building_block.id
  domain_id = opentelekomcloud_identity_group_v3.building_block.domain_id
  role_id   = each.value.id
}

resource "opentelekomcloud_identity_role_assignment_v3" "project" {
  for_each = data.opentelekomcloud_identity_role_v3.project

  group_id     = opentelekomcloud_identity_group_v3.building_block.id
  domain_id    = opentelekomcloud_identity_group_v3.building_block.domain_id
  all_projects = true
  role_id      = each.value.id
}

locals {
  federation_enabled = var.identity_provider != null
  oidc_enabled       = local.federation_enabled && try(var.identity_provider.protocol == "oidc", false)
  saml_enabled       = local.federation_enabled && try(var.identity_provider.protocol == "saml", false)
}

# Sign-in fails with O011 when the matching rules assign no group, so the base rule puts every
# federated user in this group, which holds no role.
resource "opentelekomcloud_identity_group_v3" "federated" {
  lifecycle {
    enabled = local.federation_enabled
  }

  name        = "${var.user_name}-federated"
  description = "Every federated user; holds no role. Project groups grant the permissions."
}

# T Cloud Public stores the signing keys and SAML metadata instead of fetching them, so a key or
# certificate rotation at the IdP breaks sign-in until the next run copies the current ones over.
data "http" "saml_metadata" {
  lifecycle {
    enabled = local.saml_enabled

    postcondition {
      condition     = self.status_code == 200 && strcontains(self.response_body, "EntityDescriptor")
      error_message = "${self.url} answered ${self.status_code} without SAML metadata. Use the URL the identity provider publishes its federation metadata XML at."
    }
  }

  url = var.identity_provider.metadata_url
}

data "http" "oidc_discovery" {
  lifecycle {
    enabled = local.oidc_enabled

    postcondition {
      condition     = self.status_code == 200
      error_message = "${self.url} answered ${self.status_code}. The OIDC issuer URL must be the issuer itself, without /.well-known/openid-configuration."
    }

    # T Cloud Public rejects tokens whose iss differs from the configured provider URL. The try
    # swallows a body that is not JSON, which the status check above already reports.
    postcondition {
      condition     = try(jsondecode(self.response_body).issuer, null) == var.identity_provider.oidc.provider_url
      error_message = "The discovery document names the issuer ${try(jsondecode(self.response_body).issuer, "(none)")}. Use exactly that as the OIDC issuer URL."
    }
  }

  url = "${trimsuffix(var.identity_provider.oidc.provider_url, "/")}/.well-known/openid-configuration"
}

data "http" "oidc_jwks" {
  lifecycle {
    enabled = local.oidc_enabled

    postcondition {
      condition     = self.status_code == 200
      error_message = "${self.url} answered ${self.status_code}."
    }
  }

  url = jsondecode(data.http.oidc_discovery.response_body).jwks_uri
}

resource "opentelekomcloud_identity_provider" "this" {
  lifecycle {
    enabled = local.federation_enabled

    # The federation mapping building block owns the rules; this only seeds the mapping so that it is
    # never empty.
    ignore_changes = [mapping_rules]
  }

  name        = var.identity_provider.name
  protocol    = var.identity_provider.protocol
  description = "Company identity provider; meshStack maps project users into project groups."
  status      = true
  metadata    = local.saml_enabled ? data.http.saml_metadata.response_body : null

  # Lets any federated user sign in as a virtual user named after their email, with no permission.
  mapping_rules = jsonencode([
    {
      local  = [{ user = { name = "{0}" } }, { group = { name = opentelekomcloud_identity_group_v3.federated.name } }]
      remote = [{ type = var.identity_provider.email_attribute }]
    }
  ])

  dynamic "access_config" {
    for_each = local.oidc_enabled ? [var.identity_provider.oidc] : []

    content {
      access_type            = "program_console"
      provider_url           = access_config.value.provider_url
      client_id              = access_config.value.client_id
      signing_key            = data.http.oidc_jwks.response_body
      authorization_endpoint = jsondecode(data.http.oidc_discovery.response_body).authorization_endpoint
      scopes                 = access_config.value.scopes

      # The provider leaves these unset, but IAM requires them for console access.
      response_type = "id_token"
      response_mode = "fragment"
    }
  }
}

# OBS bucket names are unique across all of T Cloud Public, not just the domain.
resource "random_string" "bucket_suffix" {
  lifecycle {
    enabled = local.federation_enabled
  }

  length  = 8
  special = false
  upper   = false
}

# Every project building block records its group membership here as `mappings/<project>.json`, and
# the federation mapping building block rebuilds the identity provider's mapping from all of them.
resource "opentelekomcloud_obs_bucket" "mappings" {
  lifecycle {
    enabled = local.federation_enabled

    # The federation mapping building block's OBS trigger adds a notification to the bucket.
    ignore_changes = [event_notifications]
  }

  bucket = "${var.user_name}-mappings-${random_string.bucket_suffix.result}"
  acl    = "private"
}

resource "opentelekomcloud_obs_bucket_policy" "mappings" {
  lifecycle {
    enabled = local.federation_enabled
  }

  bucket = opentelekomcloud_obs_bucket.mappings.bucket
  policy = jsonencode({
    Statement = [{
      Sid       = "ProjectBuildingBlocksWriteMembership"
      Effect    = "Allow"
      Principal = { ID = ["domain/${opentelekomcloud_identity_user_v3.building_block.domain_id}:user/${opentelekomcloud_identity_user_v3.building_block.id}"] }
      Action    = ["GetObject", "PutObject", "DeleteObject", "ListBucket"]
      Resource  = [opentelekomcloud_obs_bucket.mappings.bucket, "${opentelekomcloud_obs_bucket.mappings.bucket}/mappings/*"]
    }]
  })
}
