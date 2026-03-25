# ── Team-based access management ─────────────────────────────────────────────
#
# Workspace members are organized into Forgejo organization teams
# (admins / writers / readers) with appropriate permissions.
#
# We use restapi_object for team CRUD because the forgejo_team resource in the
# svalabs provider requires Forgejo site-admin privileges (calls /api/v1/admin/orgs).
# The org-level API POST /api/v1/orgs/{org}/teams only needs org-owner rights.

resource "random_string" "team_suffix" {
  length  = 8
  lower   = true
  numeric = false
  upper   = false
  special = false
}

locals {
  # Replace digits with leet-speak letter equivalents so the name satisfies ^[a-z](?:[-.]?[a-z]){1,63}$
  sanitized_workspace_id = join("", [for ch in regexall(".", lower(var.workspace_identifier)) : lookup({
    "0" = "o", "1" = "l", "2" = "z", "3" = "e", "4" = "a",
    "5" = "s", "6" = "g", "7" = "t", "8" = "b", "9" = "p",
    "_" = "-"
  }, ch, ch)])

  # Map each workspace member to a team type based on their roles (keyed by display username)
  member_team_type = {
    for member in var.workspace_members : member.username => (
      contains(member.roles, "Workspace Owner") ? "admins" : (
        contains(member.roles, "Workspace Manager") ? "writers" : "readers"
      )
    )
  }

  # Map euid (Forgejo username) to team type for API calls
  member_euid_team = {
    for member in var.workspace_members : member.euid => (
      contains(member.roles, "Workspace Owner") ? "admins" : (
        contains(member.roles, "Workspace Manager") ? "writers" : "readers"
      )
    )
  }

  # Group members by team type (using euid as Forgejo username)
  team_members = {
    for type in ["admins", "writers", "readers"] : type => [
      for euid, team_type in local.member_euid_team : euid if team_type == type
    ]
  }

  # Only create teams that have members
  active_teams = {
    for type, members in local.team_members : type => members if length(members) > 0
  }

  # Map team types to Forgejo permissions
  team_permissions = {
    admins  = "owner"
    writers = "write"
    readers = "read"
  }

  # Units to grant per team type
  team_units = {
    admins  = ["repo.code", "repo.issues", "repo.ext_issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.ext_wiki", "repo.actions"]
    writers = ["repo.code", "repo.issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.actions"]
    readers = ["repo.code", "repo.issues", "repo.wiki", "repo.pulls", "repo.releases"]
  }

  team_names = {
    for type in keys(local.active_teams) : type => "${local.sanitized_workspace_id}-${type}-${random_string.team_suffix.result}"
  }

  # Flat map for member assignments: "type/euid" => { team_type, euid }
  member_assignments = merge([
    for type, members in local.active_teams : {
      for euid in members : "${type}/${euid}" => {
        team_type = type
        euid      = euid
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

# Add members to their respective team by Forgejo username (euid).
# Uses terraform_data + local-exec because PUT /teams/{id}/members/{username}
# returns 204 No Content which restapi_object cannot handle for state tracking.
resource "terraform_data" "team_member" {
  for_each = local.member_assignments

  triggers_replace = {
    team_id = local._team_ids[each.value.team_type]
    euid    = each.value.euid
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -sf -X PUT \
        -H "Authorization: token $FORGEJO_API_TOKEN" \
        "$FORGEJO_HOST/api/v1/teams/${local._team_ids[each.value.team_type]}/members/${each.value.euid}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -sf -X DELETE \
        -H "Authorization: token $FORGEJO_API_TOKEN" \
        "$FORGEJO_HOST/api/v1/teams/${self.triggers_replace.team_id}/members/${self.triggers_replace.euid}" \
        || true
    EOT
  }
}
