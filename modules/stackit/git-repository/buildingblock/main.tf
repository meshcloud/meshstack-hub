provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

data "external" "forgejo_env" {
  program = ["python3", "-c", <<-PY
import json
import os

print(json.dumps(dict(os.environ)))
PY
  ]
}

provider "restapi" {
  uri                  = data.external.forgejo_env.result["FORGEJO_HOST"]
  write_returns_object = true

  headers = {
    Authorization = "token ${data.external.forgejo_env.result["FORGEJO_API_TOKEN"]}"
    Content-Type  = "application/json"
  }
}

provider "restapi" {
  alias                = "action_secret"
  uri                  = data.external.forgejo_env.result["FORGEJO_HOST"]
  write_returns_object = false

  headers = {
    Authorization = "token ${data.external.forgejo_env.result["FORGEJO_API_TOKEN"]}"
    Content-Type  = "application/json"
  }
}

locals {
  have_clone_addr = trimspace(var.clone_addr) != "" && var.clone_addr != "null"

  mapped_workspace_members = {
    for member in var.workspace_members : trimspace(member.username) => (
      contains(member.roles, "admin") ? "admin" : (
        contains(member.roles, "user") ? "write" : (
          contains(member.roles, "reader") ? "read" : null
        )
      )
    )
    if trimspace(member.username) != "" && (
      contains(member.roles, "admin") ||
      contains(member.roles, "user") ||
      contains(member.roles, "reader")
    )
  }
}

data "external" "current_collaborators" {
  program = ["python3", "${path.module}/get_forgejo_collaborators.py"]

  query = {
    owner = var.forgejo_organization
    repo  = forgejo_repository.this.name
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
  create_path  = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/variables"
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

resource "terraform_data" "sync_repository_collaborators" {
  depends_on = [
    forgejo_repository.this,
    restapi_object.action_secret,
    restapi_object.action_variable,
  ]

  triggers_replace = [
    sha256(file("${path.module}/reconcile_forgejo_collaborators.py")),
    sha256(file("${path.module}/get_forgejo_collaborators.py")),
    sha256(jsonencode(local.mapped_workspace_members)),
    data.external.current_collaborators.result.current_hash,
  ]

  provisioner "local-exec" {
    command = "python3 ${path.module}/reconcile_forgejo_collaborators.py"
    environment = {
      FORGEJO_HOST                 = data.external.forgejo_env.result["FORGEJO_HOST"]
      FORGEJO_API_TOKEN            = data.external.forgejo_env.result["FORGEJO_API_TOKEN"]
      REPOSITORY_OWNER             = var.forgejo_organization
      REPOSITORY_NAME              = forgejo_repository.this.name
      DESIRED_COLLABORATORS_JSON   = jsonencode(local.mapped_workspace_members)
      CURRENT_COLLABORATORS_JSON   = data.external.current_collaborators.result.collaborators_json
      PROTECTED_COLLABORATORS_JSON = jsonencode([var.forgejo_organization])
    }
  }
}
