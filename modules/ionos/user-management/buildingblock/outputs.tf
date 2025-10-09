output "all_users" {
  description = "All users (existing and newly created) organized by role"
  value = {
    readers = [
      for user in local.all_reader_users : {
        id         = user.id
        email      = user.email
        first_name = user.first_name
        last_name  = user.last_name
        roles      = ["reader"]
      }
    ]
    users = [
      for user in local.all_standard_users : {
        id         = user.id
        email      = user.email
        first_name = user.first_name
        last_name  = user.last_name
        roles      = ["user"]
      }
    ]
    administrators = [
      for user in local.all_admin_users : {
        id         = user.id
        email      = user.email
        first_name = user.first_name
        last_name  = user.last_name
        roles      = ["admin"]
      }
    ]
  }
}

output "user_summary" {
  description = "Summary of user management"
  value = {
    total_readers      = length(local.all_reader_users)
    total_users        = length(local.all_standard_users)
    total_admins       = length(local.all_admin_users)
    new_users_created  = length(ionoscloud_user.new_readers) + length(ionoscloud_user.new_users) + length(ionoscloud_user.new_administrators)
  }
}