resource "stackit_service_account" "building_block" {
  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_service_account_key" "building_block" {
  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
}

resource "stackit_authorization_organization_role_assignment" "project_admin" {
  resource_id = var.organization_id
  role        = "resource-manager.admin"
  subject     = stackit_service_account.building_block.email
}
