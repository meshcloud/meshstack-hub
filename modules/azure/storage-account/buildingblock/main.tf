data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "storage_account_rg" {
  name     = var.storage_account_resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "${var.storage_account_name}${random_string.resource_code.result}"
  resource_group_name      = azurerm_resource_group.storage_account_rg.name
  location                 = azurerm_resource_group.storage_account_rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}