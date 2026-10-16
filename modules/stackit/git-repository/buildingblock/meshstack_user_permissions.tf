data "external" "resolve_forgejo_users" {
  program = ["python3", "${path.module}/resolve_forgejo_users.py"]

  query = {
    emails                  = join(",", [for m in var.workspace_members : m.email])
    stackit_project_id      = var.stackit_project_id
    stackit_git_instance_id = var.stackit_git_instance_id
  }
}

locals {
  _resolved_users = data.external.resolve_forgejo_users.result

  member_team_type = {
    for member in var.workspace_members : member.username => (
      contains(member.roles, "Workspace Owner") ? "admins" : (
        contains(member.roles, "Workspace Manager") ? "writers" : "readers"
      )
    )
  }

  _member_email_team = {
    for member in var.workspace_members : member.email => (
      contains(member.roles, "Workspace Owner") ? "admins" : (
        contains(member.roles, "Workspace Manager") ? "writers" : "readers"
      )
    )
  }

  _resolved_members = {
    for email, username in local._resolved_users : email => {
      team_type = local._member_email_team[email]
      username  = username
    } if username != "" && !startswith(email, "error:")
  }

  active_teams = {
    for type in ["admins", "writers", "readers"] : type => [
      for email, team_type in local._member_email_team : email if team_type == type
    ] if length([for email, team_type in local._member_email_team : email if team_type == type]) > 0
  }

  team_permissions = {
    admins  = "admin"
    writers = "write"
    readers = "read"
  }

  team_units = {
    admins  = ["repo.code", "repo.issues", "repo.ext_issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.ext_wiki", "repo.actions", "repo.packages"]
    writers = ["repo.code", "repo.issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.actions", "repo.packages"]
    readers = ["repo.code", "repo.issues", "repo.ext_issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.ext_wiki", "repo.actions", "repo.packages"]
  }

  team_names = {
    for type in keys(local.active_teams) : type => "${var.name}-${type}"
  }

  member_assignments = merge([
    for email, info in local._resolved_members : {
      "${info.team_type}/${info.username}" = {
        team_type = info.team_type
        username  = info.username
      }
    }
  ]...)
}

module "teams" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git/buildingblock/forgejo-teams?ref=${var.hub_git_ref}"
  providers = {
    restapi                         = restapi.with_returned_object
    restapi.without_returned_object = restapi.without_returned_object
  }

  organization = var.forgejo_organization

  teams = {
    for type in keys(local.active_teams) : type => {
      name        = local.team_names[type]
      description = "Team for workspace ${var.workspace_identifier} ${type}"
      permission  = local.team_permissions[type]
      units       = local.team_units[type]
      members     = { for member in values(local.member_assignments) : member.username => member.username if member.team_type == type }
    }
  }
}

moved {
  from = restapi_object.team
  to   = module.teams.restapi_object.team
}

locals {
  _team_ids = module.teams.team_ids
}

resource "restapi_object" "team_repo" {
  for_each = local.active_teams

  provider = restapi.without_returned_object

  path           = "/api/v1/teams/${local._team_ids[each.key]}/repos/${var.forgejo_organization}/{id}"
  object_id      = forgejo_repository.this.name
  create_method  = "PUT"
  destroy_method = "DELETE"
  data           = jsonencode({})

  ignore_server_additions = true
}

removed {
  from = terraform_data.team_member

  lifecycle {
    destroy = false
  }
}

removed {
  from = terraform_data.team_repo

  lifecycle {
    destroy = false
  }
}
