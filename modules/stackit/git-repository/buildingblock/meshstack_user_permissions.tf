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
  source    = "github.com/meshcloud/meshstack-hub//modules/stackit/git/buildingblock/forgejo-teams?ref=${var.hub_git_ref}"
  providers = { restapi = restapi.with_returned_object }

  forgejo_host      = data.external.env.result["FORGEJO_HOST"]
  forgejo_api_token = sensitive(data.external.env.result["FORGEJO_API_TOKEN"])
  organization      = var.forgejo_organization

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

moved {
  from = terraform_data.team_member
  to   = module.teams.terraform_data.member
}

locals {
  _team_ids = module.teams.team_ids
}

# PUT answers 204 No Content, which restapi_object cannot track.
resource "terraform_data" "team_repo" {
  for_each = local.active_teams

  triggers_replace = {
    team_id   = local._team_ids[each.key]
    repo_name = forgejo_repository.this.name
    org       = var.forgejo_organization
  }

  provisioner "local-exec" {
    command = <<-EOT
      for i in 1 2 3 4 5 6; do
        curl -s --fail-with-body -X PUT \
          -H "Authorization: token $FORGEJO_API_TOKEN" \
          "$FORGEJO_HOST/api/v1/teams/${local._team_ids[each.key]}/repos/${var.forgejo_organization}/${forgejo_repository.this.name}" \
          && exit 0
        echo "Attempt $i failed, retrying in 2s..." >&2
        sleep 2
      done
      exit 1
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -s --fail-with-body -X DELETE \
        -H "Authorization: token $FORGEJO_API_TOKEN" \
        "$FORGEJO_HOST/api/v1/teams/${self.triggers_replace.team_id}/repos/${self.triggers_replace.org}/${self.triggers_replace.repo_name}" \
        || true
    EOT
  }
}
