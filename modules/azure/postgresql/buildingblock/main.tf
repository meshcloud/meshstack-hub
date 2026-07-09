resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

resource "random_password" "psql_admin_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}"
}

resource "azurerm_resource_group" "postgresql" {
  name     = "rg-${var.postgresql_server_name}"
  location = var.location
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "${var.postgresql_server_name}-${random_string.resource_code.result}"
  resource_group_name = azurerm_resource_group.postgresql.name
  location            = azurerm_resource_group.postgresql.location

  administrator_login    = var.administrator_login
  administrator_password = random_password.psql_admin_password.result

  sku_name   = var.sku_name
  version    = var.postgresql_version
  storage_mb = var.storage_mb

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  public_network_access_enabled = var.public_network_access_enabled

  lifecycle {
    # Availability zone is picked by Azure at creation time when not specified;
    # ignore it so subsequent applies don't try to force the server into a new zone.
    ignore_changes = [zone]
  }
}
