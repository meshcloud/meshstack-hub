locals {
  user_role_assignments = {
    for assignment in flatten([
      for user in var.users : [
        for role in distinct(flatten([
          for meshstack_role in user.roles : lookup(var.role_mapping, meshstack_role, [])
          ])) : {
          key     = "${user.email}:${role}"
          subject = user.email
          role    = role
        }
      ]
    ]) : assignment.key => assignment
  }
}

# STACKIT accepts a user's IAM access token as Vault token, so these roles are all a person needs.
resource "stackit_authorization_project_role_assignment" "users" {
  for_each = local.user_role_assignments

  resource_id = var.project_id
  role        = each.value.role
  subject     = each.value.subject
}
