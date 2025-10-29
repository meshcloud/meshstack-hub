# Create IONOS contract and manage API tokens
resource "ionoscloud_user" "ionos_service_user" {
  first_name     = "Terraform"
  last_name      = "Service"
  email          = var.service_user_email
  password       = var.initial_password
  administrator  = true
  force_sec_auth = false
}

# Create a group for managing DCD environments
resource "ionoscloud_group" "dcd_managers" {
  name                           = var.group_name
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
}

# Add the service user to the DCD managers group
resource "ionoscloud_user" "group_assignment" {
  user_id  = ionoscloud_user.ionos_service_user.id
  group_id = ionoscloud_group.dcd_managers.id
}