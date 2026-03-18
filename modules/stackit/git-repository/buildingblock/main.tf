provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

data "external" "forgejo_env" {
  program = ["python3", "-c", <<-PY
import json
import os

print(json.dumps({
  "forgejo_host": os.environ["FORGEJO_HOST"],
  "forgejo_auth_header": f'token {os.environ["FORGEJO_API_TOKEN"]}',
}))
PY
  ]
}

provider "restapi" {
  uri                  = data.external.forgejo_env.result.forgejo_host
  write_returns_object = true

  headers = {
    Authorization = data.external.forgejo_env.result.forgejo_auth_header
    Content-Type  = "application/json"
  }
}

locals {
  have_clone_addr = trimspace(var.clone_addr) != "" && var.clone_addr != "null"
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

resource "forgejo_repository_action_secret" "this" {
  for_each = var.action_secrets

  repository_id = forgejo_repository.this.id
  name          = each.key
  data          = each.value
}

resource "restapi_object" "action_variable" {
  for_each = var.action_variables

  path          = "/api/v1/repos/${var.forgejo_organization}/${forgejo_repository.this.name}/actions/variables/${each.key}"
  id_attribute  = "name"
  object_id     = each.key
  update_method = "PUT"
  data = jsonencode({
    value = each.value
  })
  ignore_server_additions = true
}

moved {
  from = forgejo_repository.repository
  to   = forgejo_repository.this
}

moved {
  from = forgejo_repository_action_secret.action_secrets
  to   = forgejo_repository_action_secret.this
}

moved {
  from = restapi_object.action_variables
  to   = restapi_object.action_variable
}
