# The T Cloud Public Network building block names a VPC and its only subnet alike. Both lookups fail
# with the provider's "returned no results" error when that building block has not run in this
# project yet.
data "opentelekomcloud_vpc_v1" "network" {
  name = var.network_name
}

data "opentelekomcloud_vpc_subnet_v1" "network" {
  vpc_id = data.opentelekomcloud_vpc_v1.network.id
  name   = var.network_name
}

module "cce" {
  source = "git::https://github.com/iits-consulting/terraform-opentelekomcloud-cce.git?ref=v7.6.0"

  name            = var.name
  cluster_version = var.cluster_version

  cluster_vpc_id        = data.opentelekomcloud_vpc_v1.network.id
  cluster_subnet_id     = data.opentelekomcloud_vpc_subnet_v1.network.id
  cluster_public_access = var.public_api

  node_availability_zones = toset(var.availability_zones)
  node_count              = var.node_count
  node_flavor             = var.node_flavor

  # The upstream default SATA is no longer offered; CCE answers "Unsupported volume type SATA".
  # General-purpose SSD is the plain choice among what it lists.
  node_storage_type = "GPSSD"

  # Encrypted node volumes need an EVSAccessKMS agency in the domain, which a fresh project lacks.
  node_storage_encryption_enabled = false
}
