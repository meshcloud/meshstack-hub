# Create the Azure DevOps project
resource "azuredevops_project" "main" {
  name               = var.project_name
  description        = var.project_description
  visibility         = var.project_visibility
  version_control    = var.version_control
  work_item_template = var.work_item_template

  features = var.project_features
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

# Create user entitlements and assign licenses
resource "azuredevops_user_entitlement" "users" {
  for_each = {
    for user in var.users : user.principal_name => user
  }

  principal_name       = each.value.principal_name
  account_license_type = each.value.license_type
}

# Group users by their roles for easier management
locals {
  readers = [
    for user in var.users : user.principal_name
    if user.role == "reader"
  ]
  
  contributors = [
    for user in var.users : user.principal_name
    if user.role == "contributor"
  ]
  
  administrators = [
    for user in var.users : user.principal_name
    if user.role == "administrator"
  ]
}

# Add users to project groups based on their roles
resource "azuredevops_group_membership" "readers" {
  count = length(local.readers) > 0 ? 1 : 0
  
  group = data.azuredevops_group.project_readers.descriptor
  members = [
    for email in local.readers : azuredevops_user_entitlement.users[email].descriptor
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "contributors" {
  count = length(local.contributors) > 0 ? 1 : 0
  
  group = data.azuredevops_group.project_contributors.descriptor
  members = [
    for email in local.contributors : azuredevops_user_entitlement.users[email].descriptor
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "administrators" {
  count = length(local.administrators) > 0 ? 1 : 0
  
  group = data.azuredevops_group.project_administrators.descriptor
  members = [
    for email in local.administrators : azuredevops_user_entitlement.users[email].descriptor
  ]
  mode = "add"
}

# Optional: Create custom groups if requested
resource "azuredevops_group" "custom_readers" {
  count = var.create_custom_groups ? 1 : 0
  
  scope        = azuredevops_project.main.id
  display_name = "${var.project_name} Custom Readers"
  description  = "Custom readers group for ${var.project_name} project"
}

resource "azuredevops_group" "custom_contributors" {
  count = var.create_custom_groups ? 1 : 0
  
  scope        = azuredevops_project.main.id
  display_name = "${var.project_name} Custom Contributors"
  description  = "Custom contributors group for ${var.project_name} project"
}

resource "azuredevops_group" "custom_administrators" {
  count = var.create_custom_groups ? 1 : 0
  
  scope        = azuredevops_project.main.id
  display_name = "${var.project_name} Custom Administrators" 
  description  = "Custom administrators group for ${var.project_name} project"
}