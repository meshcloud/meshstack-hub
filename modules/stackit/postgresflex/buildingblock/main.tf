data "stackit_postgresflex_flavors" "available" {
  count = local.create_instance ? 1 : 0

  project_id = var.project_id
  region     = var.stackit_region
}

data "stackit_public_ip_ranges" "stackit" {
  count = local.create_instance && var.allow_stackit_public_ip_ranges ? 1 : 0
}

# Database-only mode reads the shared instance instead of creating one, so the module can still
# return the host, the port and the instance details the summary shows.
data "stackit_postgresflex_instance" "existing" {
  count = local.create_instance ? 0 : 1

  project_id  = var.project_id
  region      = var.stackit_region
  instance_id = var.existing_instance_id
}

locals {
  # `existing_instance_id` picks the mode. Unset, the module creates the instance, the database and
  # the user as one unit. Set, the module creates only the database and the user inside an instance
  # that already exists, which is how several tenants share one instance.
  create_instance = var.existing_instance_id == null

  # The splat yields an empty list when the data source is switched off, so no conditional is needed.
  acl = distinct(concat(var.acl, flatten(data.stackit_public_ip_ranges.stackit[*].cidr_list)))

  # STACKIT encodes the node count in the flavor, so a single flavor ID carries CPU, RAM and
  # "Single" or "Replica" at once. The module takes the three as separate inputs and resolves the
  # matching flavor here, because `flavor_id` is the only non-deprecated way to set the shape.
  node_type = var.replicas == 1 ? "Single" : "Replica"

  offered_flavors = flatten(data.stackit_postgresflex_flavors.available[*].flavors)

  matching_flavors = [
    for flavor in local.offered_flavors : flavor
    if flavor.cpu == var.flavor_cpu && flavor.memory == var.flavor_ram && flavor.node_type == local.node_type
  ]

  flavor_id = length(local.matching_flavors) == 1 ? local.matching_flavors[0].id : null

  available_flavors = join(", ", [
    for flavor in local.offered_flavors :
    "${flavor.cpu} CPU / ${flavor.memory} GiB / ${flavor.node_type}"
  ])
}

resource "stackit_postgresflex_instance" "this" {
  count = local.create_instance ? 1 : 0

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

locals {
  # Exactly one of the resource and the data source has a count of 1, so one splat carries the value
  # and the other yields an empty list that `one` turns into null.
  instance_id      = local.create_instance ? one(stackit_postgresflex_instance.this[*].instance_id) : var.existing_instance_id
  instance_name    = local.create_instance ? one(stackit_postgresflex_instance.this[*].name) : one(data.stackit_postgresflex_instance.existing[*].name)
  instance_version = local.create_instance ? one(stackit_postgresflex_instance.this[*].version) : one(data.stackit_postgresflex_instance.existing[*].version)

  # In database-only mode the module does not own the ACL, so the summary reports the ACL the
  # instance actually carries rather than the value of `acl`, which has no effect in that mode.
  instance_acl = local.create_instance ? local.acl : one(data.stackit_postgresflex_instance.existing[*].network.acl)

  host = local.create_instance ? one(stackit_postgresflex_instance.this[*].connection_info.write.host) : one(data.stackit_postgresflex_instance.existing[*].connection_info.write.host)
  port = local.create_instance ? one(stackit_postgresflex_instance.this[*].connection_info.write.port) : one(data.stackit_postgresflex_instance.existing[*].connection_info.write.port)
}

# The instance had no `count` before database-only mode existed, so an instance created earlier sits
# in state under the address without an index. This block moves it to index zero instead of letting
# the next run destroy it and create a new one.
moved {
  from = stackit_postgresflex_instance.this
  to   = stackit_postgresflex_instance.this[0]
}

resource "stackit_postgresflex_user" "this" {
  project_id  = var.project_id
  region      = var.stackit_region
  instance_id = local.instance_id
  username    = var.database_username
  roles       = var.database_user_roles
}

resource "stackit_postgresflex_database" "this" {
  project_id  = var.project_id
  region      = var.stackit_region
  instance_id = local.instance_id
  name        = var.database_name
  owner       = stackit_postgresflex_user.this.username
}

locals {
  # The password can contain characters that a URL reserves, so it goes through `urlencode`. The
  # rest of the value is constrained by the input validations and needs no escaping.
  connection_string = "postgresql://${stackit_postgresflex_user.this.username}:${urlencode(stackit_postgresflex_user.this.password)}@${local.host}:${local.port}/${stackit_postgresflex_database.this.name}?sslmode=require"
}
