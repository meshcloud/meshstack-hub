# The instance, the database and the owner user live in `./database`, a module that declares no
# provider configuration. This root supplies the `stackit` provider that module needs and is what
# meshStack runs when an application team orders the building block.
#
# A composition that creates one database per tenant inside a shared instance sources `./database`
# instead, configures the `stackit` provider itself and calls the module with for_each. It cannot
# call this root that way, because a module carrying its own provider configuration is a legacy
# module and OpenTofu rejects count, for_each and depends_on on every call to it.
module "database" {
  source = "./database"

  project_id     = var.project_id
  stackit_region = var.stackit_region

  existing_instance_id = var.existing_instance_id

  instance_name    = var.instance_name
  flavor_cpu       = var.flavor_cpu
  flavor_ram       = var.flavor_ram
  replicas         = var.replicas
  storage_class    = var.storage_class
  storage_size     = var.storage_size
  postgres_version = var.postgres_version

  backup_schedule = var.backup_schedule
  retention_days  = var.retention_days

  acl                            = var.acl
  allow_stackit_public_ip_ranges = var.allow_stackit_public_ip_ranges
  network_access_scope           = var.network_access_scope

  database_name       = var.database_name
  database_username   = var.database_username
  database_user_roles = var.database_user_roles
}

# The three resources used to live in this root, so every building block ordered before the move
# has them in its state under the old address. Without these blocks the next run would destroy the
# instance and create a new one, taking every database on it with it.
#
# The instance moves as a whole resource, which carries every instance key across at once. That
# covers both shapes the address has had: `[0]` since database-only mode gave the resource a count,
# and no key at all before that. A run that still holds the unkeyed shape arrives in `./database`
# as an unkeyed instance, and the `moved` block there adds the index.
moved {
  from = stackit_postgresflex_instance.this
  to   = module.database.stackit_postgresflex_instance.this
}

moved {
  from = stackit_postgresflex_user.this
  to   = module.database.stackit_postgresflex_user.this
}

moved {
  from = stackit_postgresflex_database.this
  to   = module.database.stackit_postgresflex_database.this
}
