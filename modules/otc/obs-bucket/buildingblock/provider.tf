# Credentials come from the environment the meshStack integration sets. OBS and KMS only work on a
# region's own project, and the upstream module fails the run otherwise, so the provider targets
# that project rather than the application project this building block is ordered on. The bucket
# belongs to the domain either way; only its KMS key lives in the region's project.
provider "opentelekomcloud" {
  region      = var.region
  tenant_name = var.region
}
