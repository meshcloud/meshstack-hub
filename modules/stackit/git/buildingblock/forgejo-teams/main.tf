data "http" "teams" {
  for_each = { for key, team in var.teams : key => team if team.permission == "owner" }

  url             = "${trimsuffix(var.forgejo_host, "/")}/api/v1/orgs/${var.organization}/teams?limit=50"
  request_headers = { Authorization = "token ${var.forgejo_api_token}" }

  retry {
    attempts     = 5
    min_delay_ms = 1000
    max_delay_ms = 10000
  }
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
    { for key, teams in data.http.teams : key => one([for team in jsondecode(teams.response_body) : tostring(team.id) if team.name == "Owners"]) },
    { for key, team in restapi_object.team : key => team.id },
  )

  members = merge([
    for team_key, team in var.teams : {
      for key, username in team.members : "${team_key}/${key}" => { team = team_key, username = username }
    }
  ]...)
}

# PUT answers 204 No Content, which restapi_object cannot track. Without a username the URL ends in
# `/members/` and nothing is sent until a later run knows it.
resource "terraform_data" "member" {
  for_each = local.members

  triggers_replace = {
    url = "${trimsuffix(var.forgejo_host, "/")}/api/v1/teams/${local.team_ids[each.value.team]}/members/${each.value.username}"
  }

  # A destroy provisioner can only read `self`, so the token travels in `input`.
  input = { token = var.forgejo_api_token }

  provisioner "local-exec" {
    command     = "case \"${self.triggers_replace.url}\" in */members/) exit 0 ;; esac; curl -s --fail-with-body --retry 5 --retry-all-errors -X PUT -H \"Authorization: token $FORGEJO_API_TOKEN\" \"${self.triggers_replace.url}\""
    environment = { FORGEJO_API_TOKEN = self.input.token }
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "case \"${self.triggers_replace.url}\" in */members/) exit 0 ;; esac; curl -s -X DELETE -H \"Authorization: token $FORGEJO_API_TOKEN\" \"${self.triggers_replace.url}\" || true"
    environment = { FORGEJO_API_TOKEN = self.input.token }
  }
}
