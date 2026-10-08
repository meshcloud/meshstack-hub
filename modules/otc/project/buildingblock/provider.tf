# Credentials come from the environment the meshStack integration sets. The provider requires a
# project, and the region's own project always exists. IAM resources do not depend on it: the
# provider sends them through a separate domain-scoped client.
provider "opentelekomcloud" {
  region      = var.region
  tenant_name = var.region
}
