# Credentials come from the environment the meshStack integration sets. The network lives in the
# application team's project, which is this building block's tenant.
provider "opentelekomcloud" {
  region    = var.region
  tenant_id = var.project_id
}
