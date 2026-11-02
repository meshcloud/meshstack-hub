locals {
  user_stackit_roles = {
    for user in var.users : user.email => distinct(flatten([
      for meshstack_role in user.roles : lookup(var.role_mapping, meshstack_role, [])
    ]))
  }

  users_to_check   = [for email, roles in local.user_stackit_roles : email if length(roles) > 0]
  memberships      = length(local.users_to_check) > 0 ? data.external.stackit_users.result : {}
  role_permissions = jsondecode(lookup(local.memberships, "_role_permissions", "{}"))

  unknown_users = [for email in local.users_to_check : email if local.memberships[email] == "unknown"]

  # A held role never covers itself, so a role this building block granted earlier stays managed.
  covered_roles = {
    for assignment in flatten([
      for email in local.users_to_check : [
        for role in local.user_stackit_roles[email] : {
          email = email
          role  = role
          } if local.memberships[email] != "unknown" && length(lookup(local.role_permissions, role, [])) > 0 && alltrue([
            for permission in local.role_permissions[role] : anytrue([
              for held_role in compact(split(",", local.memberships[email])) : contains(lookup(local.role_permissions, held_role, []), permission) if held_role != role
            ])
        ])
      ]
    ]) : "${assignment.email}:${assignment.role}" => assignment
  }

  user_role_assignments = {
    for assignment in flatten([
      for email, roles in local.user_stackit_roles : [
        for role in roles : {
          key     = "${email}:${role}"
          subject = email
          role    = role
        } if !contains(local.unknown_users, email) && !contains(keys(local.covered_roles), "${email}:${role}")
      ]
    ]) : assignment.key => assignment
  }
}

data "external" "stackit_users" {
  lifecycle {
    enabled = length(local.users_to_check) > 0
  }

  program = ["bash", "${path.module}/list-unknown-users.sh"]

  query = {
    resource_type = "project"
    resource_id   = var.project_id
    emails        = join(",", local.users_to_check)
  }
}

# STACKIT accepts a user's IAM access token as Vault token, so these roles are all a person needs.
resource "stackit_authorization_project_role_assignment" "users" {
  for_each = local.user_role_assignments

  resource_id = var.project_id
  role        = each.value.role
  subject     = each.value.subject
}
