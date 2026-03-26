provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

locals {
  have_clone_addr = trimspace(var.clone_addr) != "" && var.clone_addr != "null"
}

data "external" "resolve_default_branch" {
  program = ["python3", "${path.module}/resolve_default_branch.py"]

  query = {
    clone_addr = var.clone_addr
  }
}

resource "forgejo_repository" "this" {
  owner          = var.forgejo_organization
  name           = var.name
  description    = var.description
  private        = var.private
  default_branch = local.have_clone_addr ? data.external.resolve_default_branch.result["default_branch"] : var.default_branch
  auto_init      = !local.have_clone_addr

  # One-time clone (not an ongoing mirror)
  clone_addr = local.have_clone_addr ? var.clone_addr : null
  mirror     = local.have_clone_addr ? false : null
}

module "action_variables_and_secrets" {
  source = "./action-variables-and-secrets"
  providers = {
    restapi.with_returned_object    = restapi.with_returned_object
    restapi.without_returned_object = restapi.without_returned_object
  }

  repository_id    = forgejo_repository.this.id
  action_variables = var.action_variables
  action_secrets   = var.action_secrets
}
