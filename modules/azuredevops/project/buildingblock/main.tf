
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

# Get relevant secrets from Azure KeyVault
data "azurerm_key_vault" "devops" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "azure_devops_pat" {
  name         = var.pat_secret_name
  key_vault_id = data.azurerm_key_vault.devops.id
}

# Create the Azure DevOps project
resource "azuredevops_project" "main" {
  name               = var.project_name
  description        = var.project_description
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
    for email in local.readers : local.user_descriptors[email]
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "contributors" {
  count = length(local.contributors) > 0 ? 1 : 0

  group = data.azuredevops_group.project_contributors.descriptor
  members = [
    for email in local.contributors : local.user_descriptors[email]
  ]
  mode = "add"
}

resource "azuredevops_group_membership" "administrators" {
  count = length(local.administrators) > 0 ? 1 : 0

  group = data.azuredevops_group.project_administrators.descriptor
  members = [
    for email in local.administrators : local.user_descriptors[email]
  ]
  mode = "add"
}

