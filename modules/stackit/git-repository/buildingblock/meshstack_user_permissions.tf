provider "stackit" {
  default_region = "eu01"
  experiments    = ["iam"]
}

resource "random_string" "stackit_custom_role_suffix" {
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
}

resource "stackit_authorization_project_custom_role" "access" {
  resource_id = var.stackit_project_id
  name        = "access-${local.sanitized_workspace_id}-${random_string.stackit_custom_role_suffix.result}"
  description = "Minimal custom role from workspace ${var.workspace_identifier} members that access shared Forgejo instance."
  permissions = ["git.instance.get"]
}

resource "terraform_data" "access_members" {
  for_each = local.mapped_workspace_members

  depends_on = [
    stackit_authorization_project_custom_role.access
  ]

  # trigger always as we don't know when a user finally sets up his STACKIT account
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    command = "./stackit_authorization_project_role_assignment.py"
    environment = {
      RESOURCE_ID   = var.stackit_project_id
      RESOURCE_TYPE = "project"
      ROLE          = stackit_authorization_project_custom_role.access.name
      SUBJECT       = each.key
    }
  }
}

data "external" "role_assignments" {
  depends_on = [
    terraform_data.access_members
  ]
  program = ["./get_role_assignments.py"]
  query = {
    resource_id   = var.stackit_project_id
    resource_type = "project"
  }
}

locals {
  current_role_assignments = jsondecode(data.external.role_assignments.result.members)
  current_project_members = toset([
    for member in local.current_role_assignments.members : member.subject
    if member.role == stackit_authorization_project_custom_role.access.name
  ])
  pending_workspace_members = sort([
    for username in keys(local.mapped_workspace_members) : username
    if !contains(local.current_project_members, username)
  ])
}

data "external" "current_collaborators" {
  program = ["./get_forgejo_collaborators.py"]

  query = {
    owner = var.forgejo_organization
    repo  = forgejo_repository.this.name
  }
}

locals {
  mapped_workspace_members = {
    for member in var.workspace_members : trimspace(member.euid) => (
      contains(member.roles, "Workspace Owner") ? "admin" : (
        contains(member.roles, "Workspace Manager") ? "write" : (
          "read"
        )
      )
    )
  }
  # STACKIT forgejo is setup to generate usernames without the /@domain part, so we need to strip it for locating the right collaborators
  mapped_workspace_members_forgejo = {
    for k, v in local.mapped_workspace_members : replace(k, "/(.*)@(.*)/", "$1") => v
  }
}

resource "terraform_data" "sync_repository_collaborators" {
  depends_on = [
    forgejo_repository.this,
    terraform_data.access_members
  ]

  triggers_replace = [
    sha256(file("reconcile_forgejo_collaborators.py")),
    sha256(file("get_forgejo_collaborators.py")),
    sha256(jsonencode(local.mapped_workspace_members_forgejo)),
    sha256(data.external.current_collaborators.result.collaborators_json),
  ]

  provisioner "local-exec" {
    command = "./reconcile_forgejo_collaborators.py"
    environment = {
      REPOSITORY_OWNER             = var.forgejo_organization
      REPOSITORY_NAME              = forgejo_repository.this.name
      DESIRED_COLLABORATORS_JSON   = jsonencode(local.mapped_workspace_members_forgejo)
      CURRENT_COLLABORATORS_JSON   = data.external.current_collaborators.result.collaborators_json
      PROTECTED_COLLABORATORS_JSON = jsonencode([var.forgejo_organization])
    }
  }
}
