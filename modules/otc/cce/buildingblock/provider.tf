# Credentials come from the environment the meshStack integration sets. The cluster lives in the
# project this building block is ordered on.
provider "opentelekomcloud" {
  region    = var.region
  tenant_id = var.project_id
}
