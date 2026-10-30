locals {
  use_existing_forgejo_api_token = try(var.imports.existing_forgejo_api_token_path, null) != null
}

ephemeral "vault_kv_secret_v2" "existing_forgejo_api_token" {
  lifecycle {
    enabled = local.use_existing_forgejo_api_token
  }

  mount = var.output_to_vault.mount
  name  = var.imports.existing_forgejo_api_token_path
}

# Only an owner can make the technical user an owner, so the existing token does it. The user leaves
# again before it is deleted, which STACKIT refuses while the user is in an organization.
module "existing_organization_owner" {
  source = "./forgejo-teams"
  providers = {
    restapi                         = restapi.existing
    restapi.without_returned_object = restapi.existing
  }

  depends_on = [restapi_object.local_user]

  organization = var.forgejo_organization

  teams = var.imports == null ? {} : {
    owner = {
      name       = "Owners"
      permission = "owner"
      members    = { technical_user = local.local_user_username }
    }
  }
}

# An empty PATCH changes no setting of the organization. As the create, it lets the teams depend on
# the organization; as the delete, it leaves the organization in place.
resource "restapi_object" "adopted_forgejo_organization" {
  lifecycle {
    enabled = var.imports != null
  }

  depends_on = [module.existing_organization_owner]

  path           = "/api/v1/orgs"
  id_attribute   = "username"
  object_id      = var.forgejo_organization
  create_method  = "PATCH"
  create_path    = "/api/v1/orgs/${var.forgejo_organization}"
  update_method  = "PATCH"
  destroy_method = "PATCH"
  destroy_path   = "/api/v1/orgs/${var.forgejo_organization}"
  destroy_data   = jsonencode({})
  data           = jsonencode({})

  ignore_server_additions = true
}
