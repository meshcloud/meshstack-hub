output "all_users" {
  description = "All users (existing and newly created)"
  value = [
    for user in local.all_users : {
      id            = user.id
      email         = user.email
      first_name    = user.first_name
      last_name     = user.last_name
      administrator = user.administrator
    }
  ]
}

output "user_summary" {
  description = "Summary of user management"
  value = {
    total_users        = length(local.all_users)
    new_users_created  = length(ionoscloud_user.new_users)
    workspace_owners   = length([for user in var.users : user if contains(user.roles, "Workspace Owner")])
    workspace_managers = length([for user in var.users : user if contains(user.roles, "Workspace Manager")])
    workspace_members  = length([for user in var.users : user if contains(user.roles, "Workspace Member")])
  }
}