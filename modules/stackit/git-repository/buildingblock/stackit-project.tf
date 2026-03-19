locals {
  enable_stackit_project_access = trimspace(var.stackit_project_id) != ""

  stackit_role_subjects = {
    for username in sort(keys(local.mapped_workspace_members)) :
    username => username
  }
}

resource "stackit_authorization_project_custom_role" "forgejo_access" {
  count = local.enable_stackit_project_access ? 1 : 0

  resource_id = var.stackit_project_id
  name        = var.stackit_git_access_role_name
  description = "Minimal custom role for members that should access the shared Forgejo instance."
  permissions = var.stackit_git_access_role_permissions
}

resource "stackit_authorization_project_role_assignment" "forgejo_access_members" {
  for_each = local.enable_stackit_project_access ? local.stackit_role_subjects : {}

  resource_id = var.stackit_project_id
  role        = stackit_authorization_project_custom_role.forgejo_access[0].name
  subject     = each.value
}
