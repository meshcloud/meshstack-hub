locals {
  create_instance = var.existing_instance_id == null
  instance_id     = local.create_instance ? stackit_postgresflex_instance.this.instance_id : var.existing_instance_id
  host            = local.create_instance ? stackit_postgresflex_instance.this.connection_info.write.host : data.stackit_postgresflex_instance.existing.connection_info.write.host
  port            = local.create_instance ? stackit_postgresflex_instance.this.connection_info.write.port : data.stackit_postgresflex_instance.existing.connection_info.write.port
}

resource "stackit_postgresflex_instance" "this" {
  lifecycle {
    enabled = local.create_instance
  }

  project_id = var.project_id
  name       = var.instance.name

  # STACKIT encodes the node count in the flavor ID.
  flavor_id = var.instance.replicas == 3 ? "${var.instance.flavor}-replica" : var.instance.flavor
  version   = var.instance.postgres_version

  storage = {
    class = var.instance.storage_class
    size  = var.instance.storage_size
  }

  backup_schedule = var.instance.backup_schedule
  retention_days  = var.instance.backup_retention_days

  network = {
    acl = var.instance.acl
  }
}

data "stackit_postgresflex_instance" "existing" {
  lifecycle {
    enabled = !local.create_instance
  }

  project_id  = var.project_id
  instance_id = var.existing_instance_id
}

resource "stackit_postgresflex_user" "this" {
  project_id  = var.project_id
  instance_id = local.instance_id
  username    = var.username
  # `createdb` on a shared instance would let the user add databases next to those of other tenants.
  roles = local.create_instance ? ["login", "createdb"] : ["login"]
}

resource "stackit_postgresflex_database" "this" {
  project_id  = var.project_id
  instance_id = local.instance_id
  name        = var.database_name
  owner       = stackit_postgresflex_user.this.username
}
