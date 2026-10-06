ephemeral "vault_kv_secret_v2" "existing_forgejo_api_token" {
  lifecycle {
    enabled = var.imports != null
  }

  mount = var.output_to_vault.mount
  name  = var.imports.existing_forgejo_api_token_path
}

data "restapi_object" "existing_owners_team" {
  provider = restapi.existing

  lifecycle {
    enabled = var.imports != null
  }

  path         = "/api/v1/orgs/${var.forgejo_organization}/teams"
  query_string = "limit=50"
  search_key   = "name"
  search_value = "Owners"
}

# Only an owner can make the technical user an owner, so the existing token does it. It also removes
# the user again before the user is deleted, which STACKIT refuses while the user is in an
# organization.
resource "restapi_object" "existing_organization_owner" {
  provider = restapi.existing

  lifecycle {
    enabled = var.imports != null
  }

  depends_on = [restapi_object.local_user]

  path           = "/api/v1/teams/${data.restapi_object.existing_owners_team.id}/members/{id}"
  object_id      = local.local_user_username
  create_method  = "PUT"
  destroy_method = "DELETE"
  data           = jsonencode({})

  ignore_server_additions = true
}

# An empty PATCH changes no setting of the organization. As the create, it lets the teams depend on
# the organization; as the delete, it leaves the organization in place.
resource "restapi_object" "adopted_forgejo_organization" {
  lifecycle {
    enabled = var.imports != null
  }

  depends_on = [restapi_object.existing_organization_owner]

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
