resource "stackit_service_account" "building_block" {
  project_id = var.project_id
  name       = "mesh-spoke-network"
}

resource "stackit_service_account_key" "building_block" {
  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
}

# network.admin at org scope allows managing routing tables in the network area
# and routed networks in tenant projects. Least-privilege alternative: if STACKIT
# introduces a narrower "network.editor" role, prefer that.
resource "stackit_authorization_organization_role_assignment" "network_admin" {
  resource_id = var.organization_id
  role        = "network.admin"
  subject     = stackit_service_account.building_block.email
}
