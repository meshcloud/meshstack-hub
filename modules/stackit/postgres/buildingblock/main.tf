locals {
  create_instance = var.existing_instance_id == null

  # meshStack identifiers allow hyphens, PostgreSQL names here do not.
  tenant_name = local.create_instance ? null : replace("${var.workspace_identifier}_${var.project_identifier}", "-", "_")
}

resource "stackit_postgresflex_instance" "this" {
  lifecycle {
    enabled = local.create_instance
  }

  project_id = var.project_id
  name       = var.instance_name

  # STACKIT encodes the node count in the flavor ID.
  flavor_id = var.replicas == 3 ? "${var.flavor}-replica" : var.flavor
  version   = var.postgres_version

  storage = {
    class = var.storage_class
    size  = var.storage_size
  }

  backup_schedule = var.backup_schedule
  retention_days  = var.backup_retention_days

  network = {
    acl = var.acl
  }
}

# Earlier versions created the instance inside the database module, together with a database.
moved {
  from = module.database.stackit_postgresflex_instance.this
  to   = stackit_postgresflex_instance.this
}

module "database" {
  source = "./modules/database"

  lifecycle {
    enabled = !local.create_instance
  }

  project_id    = var.project_id
  instance_id   = var.existing_instance_id
  database_name = local.tenant_name
  username      = local.tenant_name
}
