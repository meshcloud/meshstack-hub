locals {
  # Determine the parent container ID based on environment
  selected_parent_container_id = var.environment != null ? lookup(var.parent_container_ids, var.environment, var.parent_container_id) : var.parent_container_id

  users_with_stackit_roles = [
    for user in var.users : {
      email = user.email
      roles = distinct(flatten([
        for meshstack_role in user.roles : lookup(var.role_mapping, meshstack_role, [])
      ]))
    }
  ]

  user_role_assignments = {
    for assignment in flatten([
      for user in local.users_with_stackit_roles : [
        for stackit_role in user.roles : {
          key          = "${user.email}:${stackit_role}"
          subject      = user.email
          stackit_role = stackit_role
        }
      ]
    ]) : assignment.key => assignment
  }
}

resource "stackit_resourcemanager_project" "project" {
  parent_container_id = local.selected_parent_container_id
  name                = var.project_name
  owner_email         = var.service_account_email

  # Only set labels if there are actually labels to set
  labels = length(var.labels) > 0 ? var.labels : null
}

# User role assignments (experimental IAM feature)
resource "stackit_authorization_project_role_assignment" "role_assignments" {
  for_each = local.user_role_assignments

  resource_id = stackit_resourcemanager_project.project.project_id
  role        = each.value.stackit_role
  subject     = each.value.subject
}

