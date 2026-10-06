locals {
  # `external` results are never marked sensitive, so the token is marked here instead.
  stackit_access_token = sensitive(data.external.stackit_access_token.result.access_token)

  # `<name>.git.onstackit.cloud` — STACKIT derives the instance URL from the instance name. The
  # restapi provider is configured from this rather than from the instance `url`, because a
  # provider configuration cannot depend on a resource created in the same apply: on a run that
  # creates the instance and the organization at once, that attribute is still unknown at plan time.
  forgejo_base_url = "https://${var.instance_name}.git.onstackit.cloud"

  # An adopted instance already has a technical user of that name, whose password this state does
  # not hold.
  local_user_username = var.imports == null ? var.local_user_username : "${var.local_user_username}-${random_string.import_suffix.result}"

  local_user_email = coalesce(
    var.local_user_email, "${local.local_user_username}@${var.instance_name}.git.onstackit.cloud"
  )

  forgejo_api_token = sensitive(jsondecode(restapi_object.local_user_token.create_response).sha1)

  create_forgejo_organization = var.forgejo_organization != null && var.forgejo_organization != ""
}

data "external" "stackit_access_token" {
  program = ["bash", "${path.module}/stackit-access-token.sh"]
}

module "instance" {
  source = "./modules/git-instance"

  release_on_destroy = var.release_on_destroy
  project_id         = var.stackit_project_id
  name               = var.instance_name
}

moved {
  from = stackit_git.this
  to   = module.instance.stackit_git.this
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset([var.imports.instance_id]) : toset([])
  to       = module.instance.stackit_git.this
  id       = "${var.stackit_project_id},${each.value}"
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset([var.imports.instance_id]) : toset([])
  to       = module.instance.stackit_git.released
  id       = "${var.stackit_project_id},${each.value}"
}

moved {
  from = random_string.local_user_suffix
  to   = random_string.import_suffix
}

resource "random_string" "import_suffix" {
  lifecycle {
    enabled = var.imports != null
  }

  length  = 6
  special = false
  upper   = false
}

resource "random_password" "local_user" {
  length = 32

  # STACKIT accepts at most 64 characters and the password travels through a JSON body and a basic
  # auth header, so the alphabet stays free of anything that needs escaping in either.
  override_special = "-_."
}

resource "restapi_object" "local_user" {
  provider = restapi.stackit_git

  path         = "/v1beta/projects/${var.stackit_project_id}/instances/${module.instance.instance.instance_id}/users"
  id_attribute = "username"

  # Reading one user answers `302` with the user in the body, which the provider reports as an error.
  # The collection answers `200`, so the read picks this user out of it by username.
  read_path = "/v1beta/projects/${var.stackit_project_id}/instances/${module.instance.instance.instance_id}/users"
  read_search = {
    results_key  = "users"
    search_key   = "username"
    search_value = local.local_user_username
  }

  # The API has no way to change a username or an email, so either means a different user.
  force_new = ["username", "email"]

  data = jsonencode({
    name                      = local.local_user_username
    username                  = local.local_user_username
    email                     = local.local_user_email
    password                  = random_password.local_user.result
    force_send_reset_password = false
  })

  ignore_server_additions = true
}

# Forgejo never returns a token's secret again, so the value is read from `create_response`, which
# keeps the create body in state. A read addresses the list endpoint and picks the token out by name,
# because Forgejo has no get-one-token route.
resource "restapi_object" "local_user_token" {
  depends_on = [restapi_object.local_user]

  path         = "/api/v1/users/${local.local_user_username}/tokens"
  id_attribute = "id"

  read_path = "/api/v1/users/${local.local_user_username}/tokens"
  read_search = {
    search_key   = "name"
    search_value = var.local_user_token_name
  }

  force_new = ["name", "scopes"]

  data = jsonencode({
    name   = var.local_user_token_name
    scopes = var.local_user_token_scopes
  })

  ignore_server_additions = true
}

# The gitea provider is not used here: creating the organization works, but refreshing the plan
# fails with a 403 against STACKIT Git, so every subsequent run breaks. The generic REST resource
# does the same call without that refresh behaviour.
resource "restapi_object" "forgejo_organization" {
  lifecycle {
    enabled = local.create_forgejo_organization && var.imports == null
  }

  path          = "/api/v1/orgs"
  id_attribute  = "username"
  object_id     = var.forgejo_organization
  update_method = "PATCH"

  data = jsonencode({
    username   = var.forgejo_organization
    visibility = "private"
  })

  ignore_server_additions = true

  # The provider is configured from the derived URL, so OpenTofu sees no dependency on the technical
  # user it authenticates as. The organization is created after that user exists, and deleted before
  # it, because STACKIT refuses to delete a user who is still a member of an organization.
  depends_on = [restapi_object.local_user]
}

resource "restapi_object" "shared_runner" {
  provider = restapi.stackit_git

  # STACKIT allows one runner per instance, and an adopted instance keeps the one it has.
  lifecycle {
    enabled = length(var.shared_runner_labels) > 0 && var.imports == null
  }

  path         = "/v1beta/projects/${var.stackit_project_id}/instances/${module.instance.instance.instance_id}/runner"
  read_path    = "/v1beta/projects/${var.stackit_project_id}/instances/${module.instance.instance.instance_id}/runner"
  destroy_path = "/v1beta/projects/${var.stackit_project_id}/instances/${module.instance.instance.instance_id}/runner"
  id_attribute = "id"

  force_new = ["labels"]

  data = jsonencode({
    labels = var.shared_runner_labels
  })

  ignore_server_additions = true
}
