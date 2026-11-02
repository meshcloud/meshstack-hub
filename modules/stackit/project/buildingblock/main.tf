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

  users_to_check = var.organization_id == "" ? [] : [for user in local.users_with_stackit_roles : user.email if length(setsubtract(user.roles, ["owner"])) > 0]
  memberships    = length(local.users_to_check) > 0 ? data.external.stackit_users.result : {}
  unknown_users  = [for email in local.users_to_check : email if local.memberships[email] == "unknown"]

  user_role_assignments = {
    for assignment in flatten([
      for user in local.users_with_stackit_roles : [
        for stackit_role in user.roles : {
          key          = "${user.email}:${stackit_role}"
          subject      = user.email
          stackit_role = stackit_role
        } if stackit_role == "owner" || !contains(local.unknown_users, user.email)
      ]
    ]) : assignment.key => assignment
  }
}

# The project does not exist while planning the run that creates it, so users are looked up on the
# organization. STACKIT accepts `owner` for a user without an account as an invitation, so that role
# is granted without regard to the lookup.
data "external" "stackit_users" {
  lifecycle {
    enabled = length(local.users_to_check) > 0
  }

  program = ["bash", "${path.module}/list-unknown-users.sh"]

  query = {
    resource_type = "organization"
    resource_id   = var.organization_id
    emails        = join(",", local.users_to_check)
  }
}

resource "stackit_resourcemanager_project" "project" {
  parent_container_id = local.selected_parent_container_id
  name                = var.project_name
  owner_email         = var.project_owner_email

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

