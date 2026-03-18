resource "stackit_service_account" "building_block" {
  project_id = var.project_id
  name       = "mesh-storage-bucket"
}

resource "stackit_service_account_key" "building_block" {
  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
}

resource "stackit_authorization_project_role_assignment" "object_storage" {
  resource_id = var.project_id
  role        = "object-storage.admin"
  subject     = stackit_service_account.building_block.email
}

resource "stackit_authorization_project_role_assignment" "service_account" {
  resource_id = var.project_id
  role        = "object-storage.service-account-admin"
  subject     = stackit_service_account.building_block.email
}

resource "stackit_objectstorage_credentials_group" "admin" {
  project_id = var.project_id
  name       = "mesh-storage-admin"
}

resource "stackit_objectstorage_credential" "admin" {
  project_id           = var.project_id
  credentials_group_id = stackit_objectstorage_credentials_group.admin.credentials_group_id
}
