resource "stackit_resourcemanager_project" "project" {
  parent_container_id = var.parent_container_id
  name                = var.project_name
  owner_email         = var.owner_email
  labels              = var.labels
}

# Group users by their roles
locals {
  admin_users  = { for user in var.users : user.email => user if contains(user.roles, "admin") }
  user_users   = { for user in var.users : user.email => user if contains(user.roles, "user") && !contains(user.roles, "admin") }
  reader_users = { for user in var.users : user.email => user if contains(user.roles, "reader") && !contains(user.roles, "admin") && !contains(user.roles, "user") }
}

# User role assignments (experimental IAM feature)
resource "stackit_authorization_project_role_assignment" "admin_assignments" {
  for_each = local.admin_users

  resource_id = stackit_resourcemanager_project.project.project_id
  role        = "owner"
  subject     = each.value.email
}

resource "stackit_authorization_project_role_assignment" "user_assignments" {
  for_each = local.user_users

  resource_id = stackit_resourcemanager_project.project.project_id
  role        = "editor"
  subject     = each.value.email
}

resource "stackit_authorization_project_role_assignment" "reader_assignments" {
  for_each = local.reader_users

  resource_id = stackit_resourcemanager_project.project.project_id
  role        = "viewer"
  subject     = each.value.email
}

# Optional service account creation
resource "stackit_service_account" "automation" {
  count = var.create_service_account ? 1 : 0

  project_id = stackit_resourcemanager_project.project.project_id
  name       = var.service_account_name
}