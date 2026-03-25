# ── Team-based access management ─────────────────────────────────────────────
#
# Instead of per-user STACKIT project role assignments and Forgejo collaborator
# sync, workspace members are organized into Forgejo organization teams
# (admins / writers / readers) with appropriate permissions.

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

  # Map each workspace member to a team type based on their roles
  member_team_type = {
    for member in var.workspace_members : member.username => (
      contains(member.roles, "Workspace Owner") ? "admins" : (
        contains(member.roles, "Workspace Manager") ? "writers" : "readers"
      )
    )
  }

  # Group members by team type
  team_members = {
    for type in ["admins", "writers", "readers"] : type => [
      for username, team_type in local.member_team_type : username if team_type == type
    ]
  }

  # Only create teams that have members
  active_teams = {
    for type, members in local.team_members : type => members if length(members) > 0
  }

  # Map team types to Forgejo permissions
  team_permissions = {
    admins  = "admin"
    writers = "write"
    readers = "read"
  }

  # Flat map for member invitations: "type/email" => { team_type, email }
  member_invitations = merge([
    for type, members in local.active_teams : {
      for email in members : "${type}/${email}" => {
        team_type = type
        email     = email
      }
    }
  ]...)
}

data "forgejo_organization" "this" {
  name = var.forgejo_organization
}

resource "forgejo_team" "this" {
  for_each = local.active_teams

  organization = var.forgejo_organization
  name         = "${local.sanitized_workspace_id}-${each.key}-${random_string.team_suffix.result}"
  description  = "Team for workspace ${var.workspace_identifier} ${each.key}"
  permission   = local.team_permissions[each.key]
}

# Assign each team to the repository
resource "restapi_object" "team_repo" {
  for_each = local.active_teams
  provider = restapi.team_management

  path           = "/api/v1/teams/${forgejo_team.this[each.key].id}/repos/${var.forgejo_organization}/${forgejo_repository.this.name}"
  create_path    = "/api/v1/teams/${forgejo_team.this[each.key].id}/repos/${var.forgejo_organization}/${forgejo_repository.this.name}"
  destroy_path   = "/api/v1/teams/${forgejo_team.this[each.key].id}/repos/${var.forgejo_organization}/${forgejo_repository.this.name}"
  read_path      = "/api/v1/teams/${forgejo_team.this[each.key].id}/repos"
  create_method  = "PUT"
  destroy_method = "DELETE"

  object_id    = forgejo_repository.this.name
  id_attribute = "name"

  read_search = {
    search_key   = "name"
    search_value = forgejo_repository.this.name
  }

  data = "{}"
}

# Invite members by email into their respective team
resource "restapi_object" "team_member" {
  for_each = local.member_invitations
  provider = restapi.team_management

  path           = "/api/v1/orgs/${var.forgejo_organization}/teams/${forgejo_team.this[each.value.team_type].id}/members"
  create_path    = "/api/v1/orgs/${var.forgejo_organization}/teams/${forgejo_team.this[each.value.team_type].id}/members"
  destroy_path   = "/api/v1/teams/${forgejo_team.this[each.value.team_type].id}/members/${each.value.email}"
  read_path      = "/api/v1/teams/${forgejo_team.this[each.value.team_type].id}/members"
  create_method  = "POST"
  destroy_method = "DELETE"

  object_id    = each.value.email
  id_attribute = "login"

  read_search = {
    search_key   = "login"
    search_value = each.value.email
  }

  data = jsonencode({
    email = each.value.email
  })
}
