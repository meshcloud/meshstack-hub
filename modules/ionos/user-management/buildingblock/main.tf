locals {
  readers = [
    for user in var.users : user
    if contains(user.roles, "reader")
  ]

  users = [
    for user in var.users : user
    if contains(user.roles, "user")
  ]

  administrators = [
    for user in var.users : user
    if contains(user.roles, "admin")
  ]
}

# Try to find existing users first
data "ionoscloud_user" "existing_readers" {
  count = length(local.readers)
  email = local.readers[count.index].email
}

data "ionoscloud_user" "existing_users" {
  count = length(local.users)
  email = local.users[count.index].email
}

data "ionoscloud_user" "existing_administrators" {
  count = length(local.administrators)
  email = local.administrators[count.index].email
}

# Only create users that don't exist
resource "ionoscloud_user" "new_readers" {
  count = length([
    for i, user in local.readers : user
    if try(data.ionoscloud_user.existing_readers[i].id, "") == ""
  ])
  
  first_name     = local.readers[count.index].firstName
  last_name      = local.readers[count.index].lastName
  email          = local.readers[count.index].email
  password       = var.default_user_password
  administrator  = false
  force_sec_auth = var.force_sec_auth

  lifecycle {
    prevent_destroy = true
    ignore_changes = [password]
  }
}

resource "ionoscloud_user" "new_users" {
  count = length([
    for i, user in local.users : user
    if try(data.ionoscloud_user.existing_users[i].id, "") == ""
  ])
  
  first_name     = local.users[count.index].firstName
  last_name      = local.users[count.index].lastName
  email          = local.users[count.index].email
  password       = var.default_user_password
  administrator  = false
  force_sec_auth = var.force_sec_auth

  lifecycle {
    prevent_destroy = true
    ignore_changes = [password]
  }
}

resource "ionoscloud_user" "new_administrators" {
  count = length([
    for i, user in local.administrators : user
    if try(data.ionoscloud_user.existing_administrators[i].id, "") == ""
  ])
  
  first_name     = local.administrators[count.index].firstName
  last_name      = local.administrators[count.index].lastName
  email          = local.administrators[count.index].email
  password       = var.default_user_password
  administrator  = true
  force_sec_auth = var.force_sec_auth

  lifecycle {
    prevent_destroy = true
    ignore_changes = [password]
  }
}

# Combine existing and new users
locals {
  all_reader_users = concat(
    [for d in data.ionoscloud_user.existing_readers : d if try(d.id, "") != ""],
    ionoscloud_user.new_readers
  )
  
  all_standard_users = concat(
    [for d in data.ionoscloud_user.existing_users : d if try(d.id, "") != ""],
    ionoscloud_user.new_users
  )
  
  all_admin_users = concat(
    [for d in data.ionoscloud_user.existing_administrators : d if try(d.id, "") != ""],
    ionoscloud_user.new_administrators
  )
}