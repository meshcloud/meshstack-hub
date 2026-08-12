data "stackit_postgresflex_flavors" "available" {
  project_id = var.project_id
  region     = var.stackit_region
}

data "stackit_public_ip_ranges" "stackit" {
  count = var.allow_stackit_public_ip_ranges ? 1 : 0
}

locals {
  # The splat yields an empty list when the data source is switched off, so no conditional is needed.
  acl = distinct(concat(var.acl, flatten(data.stackit_public_ip_ranges.stackit[*].cidr_list)))

  # STACKIT encodes the node count in the flavor, so a single flavor ID carries CPU, RAM and
  # "Single" or "Replica" at once. The module takes the three as separate inputs and resolves the
  # matching flavor here, because `flavor_id` is the only non-deprecated way to set the shape.
  node_type = var.replicas == 1 ? "Single" : "Replica"

  matching_flavors = [
    for flavor in data.stackit_postgresflex_flavors.available.flavors : flavor
    if flavor.cpu == var.flavor_cpu && flavor.memory == var.flavor_ram && flavor.node_type == local.node_type
  ]

  flavor_id = length(local.matching_flavors) == 1 ? local.matching_flavors[0].id : null

  available_flavors = join(", ", [
    for flavor in data.stackit_postgresflex_flavors.available.flavors :
    "${flavor.cpu} CPU / ${flavor.memory} GiB / ${flavor.node_type}"
  ])
}

resource "stackit_postgresflex_instance" "this" {
  project_id = var.project_id
  region     = var.stackit_region
  name       = var.instance_name

  flavor_id = local.flavor_id
  version   = var.postgres_version

  storage = {
    class = var.storage_class
    size  = var.storage_size
  }

  backup_schedule = var.backup_schedule
  retention_days  = var.retention_days

  # An instance is unreachable until the source range of the client is listed here. An SKE cluster
  # leaves its network behind a NAT router, so the instance sees the cluster's public egress IP.
  network = {
    acl          = local.acl
    access_scope = var.network_access_scope
  }

  lifecycle {
    precondition {
      condition     = local.flavor_id != null
      error_message = "No STACKIT flavor matches ${var.flavor_cpu} CPU, ${var.flavor_ram} GiB RAM and ${var.replicas} replica(s). Available flavors: ${local.available_flavors}."
    }
  }
}

resource "stackit_postgresflex_user" "this" {
  project_id  = var.project_id
  region      = var.stackit_region
  instance_id = stackit_postgresflex_instance.this.instance_id
  username    = var.database_username
  roles       = var.database_user_roles
}

resource "stackit_postgresflex_database" "this" {
  project_id  = var.project_id
  region      = var.stackit_region
  instance_id = stackit_postgresflex_instance.this.instance_id
  name        = var.database_name
  owner       = stackit_postgresflex_user.this.username
}
