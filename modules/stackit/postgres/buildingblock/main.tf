locals {
  create_instance = var.existing_instance_id == null

  # meshStack identifiers allow hyphens, PostgreSQL names here do not.
  tenant_name = var.workspace_identifier == null || var.project_identifier == null ? null : replace("${var.workspace_identifier}_${var.project_identifier}", "-", "_")
}

module "database" {
  source = "./modules/database"

  project_id           = var.project_id
  existing_instance_id = var.existing_instance_id

  instance = local.create_instance ? {
    name                  = var.instance_name
    flavor                = var.flavor
    replicas              = var.replicas
    storage_class         = var.storage_class
    storage_size          = var.storage_size
    postgres_version      = var.postgres_version
    backup_schedule       = var.backup_schedule
    backup_retention_days = var.backup_retention_days
    acl                   = var.acl
  } : null

  database_name = coalesce(var.database_name, local.tenant_name)
  username      = coalesce(var.username, local.tenant_name)
}
