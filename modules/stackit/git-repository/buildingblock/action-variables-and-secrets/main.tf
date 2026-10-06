locals {
  repository_path = "/api/v1/repos/${var.repository_owner}/${var.repository_name}"
}

# Only the names are unwrapped, and they have to be: they are the resource instance keys. A caller
# whose map is derived from a sensitive input makes the whole map sensitive, values and keys alike.
resource "restapi_object" "action_secret" {
  for_each = nonsensitive(toset(keys(var.action_secrets)))

  provider = restapi.without_returned_object

  path         = "${local.repository_path}/actions/secrets/${each.key}"
  create_path  = "${local.repository_path}/actions/secrets/${each.key}"
  update_path  = "${local.repository_path}/actions/secrets/${each.key}"
  destroy_path = "${local.repository_path}/actions/secrets/${each.key}"
  read_path    = "${local.repository_path}/actions/secrets"
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
    data = var.action_secrets[each.key]
  })

  ignore_server_additions = true
}

resource "restapi_object" "action_variable" {
  for_each = var.action_variables

  provider = restapi.with_returned_object

  path         = "${local.repository_path}/actions/variables/${each.key}"
  create_path  = "${local.repository_path}/actions/variables/${each.key}"
  update_path  = "${local.repository_path}/actions/variables/${each.key}"
  destroy_path = "${local.repository_path}/actions/variables/${each.key}"
  read_path    = "${local.repository_path}/actions/variables/${each.key}"
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
