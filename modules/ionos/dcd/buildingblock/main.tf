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

  # Combine existing and new users for group membership
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

# Create the datacenter
resource "ionoscloud_datacenter" "main" {
  name        = var.datacenter_name
  location    = var.datacenter_location
  description = var.datacenter_description
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
}

# Create a group for readers (read-only access)
resource "ionoscloud_group" "readers" {
  count                          = length(local.readers) > 0 ? 1 : 0
  name                           = "${var.datacenter_name}-readers"
  create_datacenter              = false
  create_snapshot                = false
  reserve_ip                     = false
  access_activity_log            = true
  s3_privilege                   = false
  create_backup_unit             = false
  create_internet_access         = false
  create_k8s_cluster             = false
  create_pcc                     = false
  create_flow_log                = false
  access_and_manage_monitoring   = true
  access_and_manage_certificates = false

  user_ids = [for user in local.all_reader_users : user.id]
}

# Create a group for standard users
resource "ionoscloud_group" "users" {
  count                          = length(local.users) > 0 ? 1 : 0
  name                           = "${var.datacenter_name}-users"
  create_datacenter              = false
  create_snapshot                = true
  reserve_ip                     = true
  access_activity_log            = true
  s3_privilege                   = true
  create_backup_unit             = true
  create_internet_access         = true
  create_k8s_cluster             = false
  create_pcc                     = false
  create_flow_log                = true
  access_and_manage_monitoring   = true
  access_and_manage_certificates = false

  user_ids = [for user in local.all_standard_users : user.id]
}

# Create a group for administrators
resource "ionoscloud_group" "administrators" {
  count                          = length(local.administrators) > 0 ? 1 : 0
  name                           = "${var.datacenter_name}-administrators"
  create_datacenter              = true
  create_snapshot                = true
  reserve_ip                     = true
  access_activity_log            = true
  s3_privilege                   = true
  create_backup_unit             = true
  create_internet_access         = true
  create_k8s_cluster             = true
  create_pcc                     = true
  create_flow_log                = true
  access_and_manage_monitoring   = true
  access_and_manage_certificates = true

  user_ids = [for user in local.all_admin_users : user.id]
}

# Grant group access to the datacenter
resource "ionoscloud_share" "readers" {
  count           = length(local.readers) > 0 ? 1 : 0
  group_id        = ionoscloud_group.readers[0].id
  resource_id     = ionoscloud_datacenter.main.id
  edit_privilege  = false
  share_privilege = false
}

resource "ionoscloud_share" "users" {
  count           = length(local.users) > 0 ? 1 : 0
  group_id        = ionoscloud_group.users[0].id
  resource_id     = ionoscloud_datacenter.main.id
  edit_privilege  = true
  share_privilege = false
}

resource "ionoscloud_share" "administrators" {
  count           = length(local.administrators) > 0 ? 1 : 0
  group_id        = ionoscloud_group.administrators[0].id
  resource_id     = ionoscloud_datacenter.main.id
  edit_privilege  = true
  share_privilege = true
}