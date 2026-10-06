data "restapi_object" "owners_team" {
  for_each = { for key, team in var.teams : key => team if team.permission == "owner" }

  path         = "/api/v1/orgs/${var.organization}/teams"
  query_string = "limit=50"
  search_key   = "name"
  search_value = "Owners"
}

# Not forgejo_team, which needs site admin (/api/v1/admin/orgs).
resource "restapi_object" "team" {
  for_each = { for key, team in var.teams : key => team if team.permission != "owner" }

  path          = "/api/v1/orgs/${var.organization}/teams"
  read_path     = "/api/v1/teams/{id}"
  update_path   = "/api/v1/teams/{id}"
  destroy_path  = "/api/v1/teams/{id}"
  update_method = "PATCH"
  id_attribute  = "id"

  data = jsonencode({
    name                      = each.value.name
    description               = each.value.description
    permission                = each.value.permission
    includes_all_repositories = each.value.includes_all_repositories
    units                     = each.value.units
  })

  # Forgejo adds fields such as `organization` and `units_map` to the team.
  ignore_server_additions = true
}

locals {
  team_ids = merge(
    { for key, team in data.restapi_object.owners_team : key => team.id },
    { for key, team in restapi_object.team : key => team.id },
  )

  members = merge([
    for team_key, team in var.teams : {
      for key, username in team.members : "${team_key}/${key}" => { team = team_key, username = username }
      if username != ""
    }
  ]...)
}

resource "restapi_object" "member" {
  for_each = local.members

  provider = restapi.without_returned_object

  path           = "/api/v1/teams/${local.team_ids[each.value.team]}/members/{id}"
  object_id      = each.value.username
  create_method  = "PUT"
  destroy_method = "DELETE"
  data           = jsonencode({})

  ignore_server_additions = true
}

removed {
  from = terraform_data.member

  lifecycle {
    destroy = false
  }
}
