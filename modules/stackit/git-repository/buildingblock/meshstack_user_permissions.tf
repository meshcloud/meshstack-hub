# ── Team-based access management ─────────────────────────────────────────────
#
# Workspace members are organized into Forgejo organization teams
# (admins / writers / readers) with appropriate permissions.
#
# We use restapi_object for team CRUD because the forgejo_team resource in the
# svalabs provider requires Forgejo site-admin privileges (calls /api/v1/admin/orgs).
# The org-level API POST /api/v1/orgs/{org}/teams only needs org-owner rights.
#
# Members are looked up by email via the Forgejo search API. Only members whose
# email resolves to an existing Forgejo account are added to teams. Members who
# haven't signed into the Forgejo instance yet are reported in the summary.

resource "random_string" "team_suffix" {
  length  = 8
  lower   = true
  numeric = false
  upper   = false
  special = false
}

# Resolve workspace member emails to Forgejo usernames
data "external" "resolve_forgejo_users" {
  program = ["python3", "${path.module}/resolve_forgejo_users.py"]

  query = {
    emails = join(",", [for m in var.workspace_members : m.email])
  }
}

locals {
  # email → forgejo username (empty string if not found)
  _resolved_users = data.external.resolve_forgejo_users.result

  # Map each workspace member to a team type based on their roles (keyed by email)
  member_team_type = {
    for member in var.workspace_members : member.username => (
      contains(member.roles, "Workspace Owner") ? "admins" : (
        contains(member.roles, "Workspace Manager") ? "writers" : "readers"
      )
    )
  }

  # Map email → team type
  _member_email_team = {
    for member in var.workspace_members : member.email => (
      contains(member.roles, "Workspace Owner") ? "admins" : (
        contains(member.roles, "Workspace Manager") ? "writers" : "readers"
      )
    )
  }

  # Members with resolved Forgejo accounts: email → { team_type, username }
  _resolved_members = {
    for email, username in local._resolved_users : email => {
      team_type = local._member_email_team[email]
      username  = username
    } if username != ""
  }

  # Members without Forgejo accounts (for summary reporting)
  _unresolved_members = {
    for email, username in local._resolved_users : email => {
      team_type = local._member_email_team[email]
    } if username == ""
  }

  # Group members by team type (using resolved emails)
  team_members = {
    for type in ["admins", "writers", "readers"] : type => [
      for email, info in local._resolved_members : email if info.team_type == type
    ]
  }

  # All team types that have at least one workspace member assigned (resolved or not)
  active_teams = {
    for type in ["admins", "writers", "readers"] : type => [
      for email, team_type in local._member_email_team : email if team_type == type
    ] if length([for email, team_type in local._member_email_team : email if team_type == type]) > 0
  }

  # Map team types to Forgejo permissions
  team_permissions = {
    admins  = "admin"
    writers = "write"
    readers = "read"
  }

  # Units to grant per team type
  team_units = {
    admins  = ["repo.code", "repo.issues", "repo.ext_issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.ext_wiki", "repo.actions", "repo.packages"]
    writers = ["repo.code", "repo.issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.actions", "repo.packages"]
    readers = ["repo.code", "repo.issues", "repo.ext_issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.ext_wiki", "repo.actions", "repo.packages"]
  }

  team_names = {
    for type in keys(local.active_teams) : type => "${var.workspace_identifier}-${type}-${random_string.team_suffix.result}"
  }

  # Flat map for resolved member assignments: "type/username" => { team_type, username }
  member_assignments = merge([
    for email, info in local._resolved_members : {
      "${info.team_type}/${info.username}" = {
        team_type = info.team_type
        username  = info.username
      }
    }
  ]...)
}

# Create teams via the org-level API (POST returns JSON, does not require site-admin).
# Forgejo returns extra fields (organization, units_map, etc.) and rewrites the
# permission value for owner teams to "none", so we must ignore server additions.
resource "restapi_object" "team" {
  for_each = local.active_teams
  provider = restapi.with_returned_object

  path           = "/api/v1/orgs/${var.forgejo_organization}/teams"
  create_path    = "/api/v1/orgs/${var.forgejo_organization}/teams"
  destroy_path   = "/api/v1/teams/{id}"
  read_path      = "/api/v1/teams/{id}"
  update_path    = "/api/v1/teams/{id}"
  create_method  = "POST"
  update_method  = "PATCH"
  destroy_method = "DELETE"

  id_attribute            = "id"
  ignore_server_additions = true

  data = jsonencode({
    name        = local.team_names[each.key]
    description = "Team for workspace ${var.workspace_identifier} ${each.key}"
    permission  = local.team_permissions[each.key]
    units       = local.team_units[each.key]
  })
}

locals {
  # Extract numeric team IDs from restapi response for use in dependent resources
  _team_ids = {
    for type, team in restapi_object.team : type => team.id
  }
}

# Assign each team to the repository.
# Uses terraform_data + local-exec because PUT /teams/{id}/repos/{org}/{repo}
# returns 204 No Content which restapi_object cannot handle for state tracking.
resource "terraform_data" "team_repo" {
  for_each = local.active_teams

  triggers_replace = {
    team_id   = local._team_ids[each.key]
    repo_name = forgejo_repository.this.name
    org       = var.forgejo_organization
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -sf -X PUT \
        -H "Authorization: token $FORGEJO_API_TOKEN" \
        "$FORGEJO_HOST/api/v1/teams/${local._team_ids[each.key]}/repos/${var.forgejo_organization}/${forgejo_repository.this.name}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -sf -X DELETE \
        -H "Authorization: token $FORGEJO_API_TOKEN" \
        "$FORGEJO_HOST/api/v1/teams/${self.triggers_replace.team_id}/repos/${self.triggers_replace.org}/${self.triggers_replace.repo_name}" \
        || true
    EOT
  }
}

# Add resolved members to their respective team by Forgejo username.
# Uses terraform_data + local-exec because PUT /teams/{id}/members/{username}
# returns 204 No Content which restapi_object cannot handle for state tracking.
resource "terraform_data" "team_member" {
  for_each = local.member_assignments

  triggers_replace = {
    team_id  = local._team_ids[each.value.team_type]
    username = each.value.username
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -sf -X PUT \
        -H "Authorization: token $FORGEJO_API_TOKEN" \
        "$FORGEJO_HOST/api/v1/teams/${local._team_ids[each.value.team_type]}/members/${each.value.username}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -sf -X DELETE \
        -H "Authorization: token $FORGEJO_API_TOKEN" \
        "$FORGEJO_HOST/api/v1/teams/${self.triggers_replace.team_id}/members/${self.triggers_replace.username}" \
        || true
    EOT
  }
}
