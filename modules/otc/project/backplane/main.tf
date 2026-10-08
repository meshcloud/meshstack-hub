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
  all_projects = true
  role_id      = each.value.id
}

locals {
  federation_enabled = var.identity_provider != null
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
  metadata    = var.identity_provider.protocol == "saml" ? var.identity_provider.metadata : null

  # Lets any federated user sign in as a virtual user named after their email, with no group and so
  # no permission.
  mapping_rules = jsonencode([
    {
      local  = [{ user = { name = "{0}" } }]
      remote = [{ type = var.identity_provider.email_attribute }]
    }
  ])

  dynamic "access_config" {
    for_each = var.identity_provider.protocol == "oidc" ? [var.identity_provider.oidc] : []

    content {
      access_type            = "program_console"
      provider_url           = access_config.value.provider_url
      client_id              = access_config.value.client_id
      signing_key            = access_config.value.signing_key
      authorization_endpoint = access_config.value.authorization_endpoint
      scopes                 = access_config.value.scopes
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
