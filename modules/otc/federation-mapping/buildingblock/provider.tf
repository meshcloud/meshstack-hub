# Credentials come from the environment the meshStack integration sets. The function runs in the
# management project, which is this building block's tenant.
provider "opentelekomcloud" {
  region    = var.region
  tenant_id = var.project_id
}
