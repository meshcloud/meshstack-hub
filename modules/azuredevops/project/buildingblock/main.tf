
# Note: License assignment is handled by the authoritative system
# Users are provided with their roles already assigned

# Group users by their roles for easier management
locals {
  readers = [
    for user in var.users : user.euid
    if contains(user.roles, "reader") || contains(user.roles, "Workspace Member")
  ]

  contributors = [
    for user in var.users : user.euid
    if contains(user.roles, "user") || contains(user.roles, "Workspace Manager")
  ]

  administrators = [
    for user in var.users : user.euid
    if contains(user.roles, "admin") || contains(user.roles, "Workspace Owner")

  ]
  # Create a map of email to user descriptor for easy lookup
  # Use ellipsis to handle duplicate principal_names, then take the first descriptor per key
  user_descriptors_grouped = {
    for user in data.azuredevops_users.all_users.users : user.principal_name => user.descriptor...
  }
  user_descriptors = {
    for key, descriptors in local.user_descriptors_grouped : key => descriptors[0]
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
    for euid in local.readers : local.user_descriptors[euid] if contains(keys(local.user_descriptors), euid)
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "contributors" {
  count = length(local.contributors) > 0 ? 1 : 0

  group = data.azuredevops_group.project_contributors.descriptor
  members = [
    for euid in local.contributors : local.user_descriptors[euid] if contains(keys(local.user_descriptors), euid)
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "administrators" {
  count = length(local.administrators) > 0 ? 1 : 0

  group = data.azuredevops_group.project_administrators.descriptor
  members = [
    for euid in local.administrators : local.user_descriptors[euid] if contains(keys(local.user_descriptors), euid)
  ]
  mode = "add"
}
