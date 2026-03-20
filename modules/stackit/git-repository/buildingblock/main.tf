provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

locals {
  restapi_provider_headers = {
    Authorization = "token ${data.external.env.result["FORGEJO_API_TOKEN"]}"
    Content-Type  = "application/json"
  }
}

provider "restapi" {
  uri     = data.external.env.result["FORGEJO_HOST"]
  headers = local.restapi_provider_headers
  # crucial flag which must be on provider level to control different handling for secrets (see below),
  # as they can't be read back to check for state
  write_returns_object = true
}

provider "restapi" {
  alias   = "action_secret"
  uri     = data.external.env.result["FORGEJO_HOST"]
  headers = local.restapi_provider_headers
  # Secrets can't be read back, so PUT/POST don't return the object
  write_returns_object = false
}

locals {
  have_clone_addr = trimspace(var.clone_addr) != "" && var.clone_addr != "null"

  mapped_workspace_members = {
    for member in var.workspace_members : trimspace(member.euid) => (
      contains(member.roles, "Workspace Owner") ? "admin" : (
        contains(member.roles, "Workspace Manager") ? "write" : (
          "read"
        )
      )
    )
  }
}

resource "forgejo_repository" "this" {
  owner          = var.forgejo_organization
  name           = var.name
  description    = var.description
  private        = var.private
  default_branch = var.default_branch
  auto_init      = !local.have_clone_addr

  # One-time clone (not an ongoing mirror)
  clone_addr = local.have_clone_addr ? var.clone_addr : null
  mirror     = false
}

resource "restapi_object" "action_secret" {
  for_each = var.action_secrets

  provider = restapi.action_secret

  path         = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/secrets/${each.key}"
  create_path  = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/secrets/${each.key}"
  update_path  = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/secrets/${each.key}"
  destroy_path = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/secrets/${each.key}"
  read_path    = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/secrets"
  id_attribute = "name"
  object_id    = each.key

  create_method  = "PUT"
  update_method  = "PUT"
  destroy_method = "DELETE"

  read_search = {
    results_key  = "data"
    search_key   = "name"
    search_value = each.key
  }

  data = jsonencode({
    data = each.value
  })

  ignore_server_additions = true
}

resource "restapi_object" "action_variable" {
  for_each = var.action_variables

  path         = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/variables/${each.key}"
  create_path  = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/variables/${each.key}"
  update_path  = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/variables/${each.key}"
  destroy_path = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/variables/${each.key}"
  read_path    = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/variables/${each.key}"
  id_attribute = "name"
  object_id    = each.key

  create_method  = "POST"
  update_method  = "PUT"
  destroy_method = "DELETE"

  data = jsonencode({
    name  = each.key
    value = each.value
  })

  ignore_server_additions = true
}

moved {
  from = forgejo_repository.repository
  to   = forgejo_repository.this
}

moved {
  from = restapi_object.action_variables
  to   = restapi_object.action_variable
}
