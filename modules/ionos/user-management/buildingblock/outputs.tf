output "all_users" {
  description = "All users (existing and newly created)"
  value = [
    for user in local.all_users_list : {
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
    total_users       = length(local.all_users_list)
    existing_users    = length(local.existing_users)
    new_users_created = length(local.users_to_create)
  }
}

output "existing_users" {
  description = "Users that already existed in IONOS"
  value = [
    for user in values(data.ionoscloud_user.existing) : {
      email = user.email
      name  = "${user.first_name} ${user.last_name}"
      id    = user.id
    }
  ]
}

output "created_users" {
  description = "Users that were newly created"
  value = [
    for user in values(ionoscloud_user.new_users) : {
      email = user.email
      name  = "${user.first_name} ${user.last_name}"
      id    = user.id
    }
  ]
}