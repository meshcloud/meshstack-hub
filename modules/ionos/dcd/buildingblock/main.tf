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

# Create reader users
resource "ionoscloud_user" "readers" {
  count          = length(local.readers)
  first_name     = local.readers[count.index].firstName
  last_name      = local.readers[count.index].lastName
  email          = local.readers[count.index].email
  password       = var.default_user_password
  administrator  = false
  force_sec_auth = var.force_sec_auth

  lifecycle {
    ignore_changes = [first_name, last_name, email]
  }
}

# Create standard users
resource "ionoscloud_user" "users" {
  count          = length(local.users)
  first_name     = local.users[count.index].firstName
  last_name      = local.users[count.index].lastName
  email          = local.users[count.index].email
  password       = var.default_user_password
  administrator  = false
  force_sec_auth = var.force_sec_auth

  lifecycle {
    ignore_changes = [first_name, last_name, email]
  }
}

# Create admin users
resource "ionoscloud_user" "administrators" {
  count          = length(local.administrators)
  first_name     = local.administrators[count.index].firstName
  last_name      = local.administrators[count.index].lastName
  email          = local.administrators[count.index].email
  password       = var.default_user_password
  administrator  = true
  force_sec_auth = var.force_sec_auth

  lifecycle {
    ignore_changes = [first_name, last_name, email]
  }
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

  user_ids = [for user in ionoscloud_user.readers : user.id]
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

  user_ids = [for user in ionoscloud_user.users : user.id]
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

  user_ids = [for user in ionoscloud_user.administrators : user.id]
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