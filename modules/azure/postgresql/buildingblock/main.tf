data "azurerm_client_config" "current" {}

ephemeral "random_password" "administrator" {
  length  = 32
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.postgresql_server_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  version    = var.postgresql_version
  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  administrator_login               = var.administrator_login
  administrator_password_wo         = ephemeral.random_password.administrator.result
  administrator_password_wo_version = 1

  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  auto_grow_enabled             = var.auto_grow_enabled
  public_network_access_enabled = var.public_network_access_enabled

  lifecycle {
    # Azure picks a zone and moves the server to another one on a failover.
    ignore_changes = [zone]
  }
}

locals {
  portal_url = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${azurerm_postgresql_flexible_server.this.id}"
}
