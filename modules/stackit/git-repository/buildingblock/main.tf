provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

provider "restapi" {
  uri                  = data.external.env.result["FORGEJO_HOST"]
  write_returns_object = true

  headers = {
    Authorization = "token ${data.external.env.result["FORGEJO_API_TOKEN"]}"
    Content-Type  = "application/json"
  }
}

provider "restapi" {
  alias                = "action_secret"
  uri                  = data.external.env.result["FORGEJO_HOST"]
  write_returns_object = false

  headers = {
    Authorization = "token ${data.external.env.result["FORGEJO_API_TOKEN"]}"
    Content-Type  = "application/json"
  }
}

locals {
  have_clone_addr = trimspace(var.clone_addr) != "" && var.clone_addr != "null"

  mapped_workspace_members = {
    for member in var.workspace_members : trimspace(member.username) => (
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

  create_method  = "PUT"
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
