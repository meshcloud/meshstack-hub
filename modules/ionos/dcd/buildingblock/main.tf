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

# Create the datacenter
resource "ionoscloud_datacenter" "main" {
  name        = var.datacenter_name
  location    = var.datacenter_location
  description = var.datacenter_description
}

# Find existing users by email (they should be created by the user-management module)
data "ionoscloud_user" "readers" {
  count = length(local.readers)
  email = local.readers[count.index].email
}

data "ionoscloud_user" "users" {
  count = length(local.users)
  email = local.users[count.index].email
}

data "ionoscloud_user" "administrators" {
  count = length(local.administrators)
  email = local.administrators[count.index].email
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

  user_ids = [for user in data.ionoscloud_user.readers : user.id]
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

  user_ids = [for user in data.ionoscloud_user.users : user.id]
}

# Create a group for administrators (same privileges as users)
resource "ionoscloud_group" "administrators" {
  count                          = length(local.administrators) > 0 ? 1 : 0
  name                           = "${var.datacenter_name}-administrators"
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

  user_ids = [for user in data.ionoscloud_user.administrators : user.id]
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
  share_privilege = false
}