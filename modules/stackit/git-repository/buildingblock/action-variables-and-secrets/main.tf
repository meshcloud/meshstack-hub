data "external" "repository_context" {
  program = ["python3", "${path.module}/get_forgejo_repository_context.py"]

  query = {
    FORGEJO_REPOSITORY_ID = tostring(var.repository_id)
  }
}

locals {
  repository_owner = data.external.repository_context.result.owner
  repository_name  = data.external.repository_context.result.name
}

resource "restapi_object" "action_secret" {
  for_each = var.action_secrets

  provider = restapi.without_returned_object

  path         = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  create_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  update_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  destroy_path = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  read_path    = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets"
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

  provider = restapi.with_returned_object

  path         = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  create_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  update_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  destroy_path = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  read_path    = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
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
