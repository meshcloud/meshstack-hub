# Try to find existing users first
data "ionoscloud_user" "existing_users" {
  count = length(var.users)
  email = var.users[count.index].email
}

# Only create users that don't exist
resource "ionoscloud_user" "new_users" {
  count = length([
    for i, user in var.users : user
    if try(data.ionoscloud_user.existing_users[i].id, "") == ""
  ])
  
  first_name     = var.users[count.index].firstName
  last_name      = var.users[count.index].lastName
  email          = var.users[count.index].email
  password       = var.default_user_password
  administrator  = contains(var.users[count.index].roles, "Workspace Owner")
  force_sec_auth = var.force_sec_auth

  lifecycle {
    prevent_destroy = true
    ignore_changes = [password]
  }
}

# Combine existing and new users
locals {
  all_users = concat(
    [for d in data.ionoscloud_user.existing_users : d if try(d.id, "") != ""],
    ionoscloud_user.new_users
  )
}