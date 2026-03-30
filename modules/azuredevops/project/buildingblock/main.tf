
# Note: License assignment is handled by the authoritative system
# Users are provided with their roles already assigned

# Group users by their roles for easier management
locals {
  readers = [
    for user in var.users : user.email
    if contains(user.roles, "reader") || contains(user.roles, "Workspace Member")
  ]

  contributors = [
    for user in var.users : user.email
    if contains(user.roles, "user") || contains(user.roles, "Workspace Manager")
  ]

  administrators = [
    for user in var.users : user.email
    if contains(user.roles, "admin") || contains(user.roles, "Workspace Owner")

  ]
  # Create a map of email to user descriptor for easy lookup
  user_descriptors = {
    for user in data.azuredevops_users.all_users.users : user.principal_name => user.descriptor
  }
}

# Create the Azure DevOps project
# NOTE: Managing project features requires a PAT with 'Full Access' scope, despite provider documentation
# suggesting more granular permissions. Custom scoped PATs will result in 401 Unauthorized errors.
# See: https://github.com/microsoft/terraform-provider-azuredevops/issues/712
# Azure DevOps's API design makes it impossible to manage certain features without full access.
resource "azuredevops_project" "main" {
  name               = var.project_name
  description        = "${var.project_name} ${var.project_description}"
  visibility         = var.project_visibility
  version_control    = var.version_control
  work_item_template = var.work_item_template

  features = var.project_features
  lifecycle {

    ignore_changes = [
      visibility,
      version_control,
      work_item_template
    ]
  }
}

# Data source to get built-in project groups
data "azuredevops_group" "project_readers" {
  project_id = azuredevops_project.main.id
  name       = "Readers"
}

data "azuredevops_group" "project_contributors" {
  project_id = azuredevops_project.main.id
  name       = "Contributors"
}

data "azuredevops_group" "project_administrators" {
  project_id = azuredevops_project.main.id
  name       = "Project Administrators"
}

# Get user descriptors for existing users
data "azuredevops_users" "all_users" {
  # This will get all users in the organization
}

# Add users to project groups based on their roles
resource "azuredevops_group_membership" "readers" {
  count = length(local.readers) > 0 ? 1 : 0

  group = data.azuredevops_group.project_readers.descriptor
  members = [
    for email in local.readers : local.user_descriptors[email] if contains(keys(local.user_descriptors), email)
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "contributors" {
  count = length(local.contributors) > 0 ? 1 : 0

  group = data.azuredevops_group.project_contributors.descriptor
  members = [
    for email in local.contributors : local.user_descriptors[email] if contains(keys(local.user_descriptors), email)
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "administrators" {
  count = length(local.administrators) > 0 ? 1 : 0

  group = data.azuredevops_group.project_administrators.descriptor
  members = [
    for email in local.administrators : local.user_descriptors[email] if contains(keys(local.user_descriptors), email)
  ]
  mode = "add"
}

resource "azuredevops_git_repository" "main" {
  project_id = azuredevops_project.main.id
  name       = "${var.repository_name}-repo"

  initialization {
    init_type = var.init_type
  }

  lifecycle {
    ignore_changes = [
      initialization
    ]
  }
}

resource "azuredevops_branch_policy_min_reviewers" "main" {
  count = var.enable_branch_policies ? 1 : 0

  project_id = azuredevops_project.main.id

  enabled  = true
  blocking = true

  settings {
    reviewer_count                         = var.minimum_reviewers
    submitter_can_vote                     = false
    last_pusher_cannot_approve             = true
    allow_completion_with_rejects_or_waits = false
    on_push_reset_approved_votes           = true

    scope {
      repository_id  = azuredevops_git_repository.main.id
      repository_ref = azuredevops_git_repository.main.default_branch
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_work_item_linking" "main" {
  count = var.enable_branch_policies ? 1 : 0

  project_id = azuredevops_project.main.id
  enabled    = true
  blocking   = false

  settings {
    scope {
      repository_id  = azuredevops_git_repository.main.id
      repository_ref = azuredevops_git_repository.main.default_branch
      match_type     = "Exact"
    }
  }
}
