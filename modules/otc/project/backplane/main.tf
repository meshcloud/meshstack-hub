data "opentelekomcloud_identity_role_v3" "domain" {
  for_each = toset(var.domain_roles)

  name = each.value
}

resource "random_password" "building_block" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>:?"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# T Cloud Public's Terraform provider cannot exchange an OIDC token, so the building block needs a
# static credential.
resource "opentelekomcloud_identity_user_v3" "building_block" {
  name        = var.user_name
  description = "meshStack: creates T Cloud Public projects and maps project users into them."
  password    = random_password.building_block.result
  access_type = "programmatic"
  pwd_reset   = false
}

resource "opentelekomcloud_identity_group_v3" "building_block" {
  name        = var.user_name
  description = "Domain roles of the meshStack project building block user."
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

locals {
  # Logs a federated user in as a virtual user named after their email, with no group and so no
  # permission. Project building blocks append one rule per project role that adds the groups. The
  # mapping must never be empty, and this rule is also what makes a user without any project still
  # able to sign in and see that they have none.
  base_mapping_rules = var.identity_provider == null ? null : jsonencode([
    {
      local  = [{ user = { name = "{0}" } }]
      remote = [{ type = var.identity_provider.email_attribute }]
    }
  ])
}

resource "opentelekomcloud_identity_provider" "this" {
  lifecycle {
    enabled = var.identity_provider != null

    # Project building blocks own every rule but the base one, so a re-apply here must not wipe them.
    ignore_changes = [mapping_rules]
  }

  name          = var.identity_provider.name
  protocol      = var.identity_provider.protocol
  description   = "Customer identity provider; meshStack project building blocks map users into project groups."
  status        = true
  metadata      = var.identity_provider.protocol == "saml" ? var.identity_provider.metadata : null
  mapping_rules = local.base_mapping_rules

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
