data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "storage_account_rg" {
  name     = "rg-${var.storage_account_name}"
  location = var.location
}

locals {
  # Premium storage only supports LRS/ZRS replication in Azure, so the BBD hides the replication
  # choice for Premium (see meshstack_integration.tf) and this is the value that applies instead.
  effective_replication_type = var.account_tier == "Premium" ? "LRS" : var.account_replication_type
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "${var.storage_account_name}${random_string.resource_code.result}"
  resource_group_name      = azurerm_resource_group.storage_account_rg.name
  location                 = azurerm_resource_group.storage_account_rg.location
  account_tier             = var.account_tier
  account_replication_type = local.effective_replication_type

  tags = var.business_unit != null ? { BusinessUnit = join(",", var.business_unit) } : {}

  blob_properties {
    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }
  }

  network_rules {
    default_action             = var.network_rules.default_action
    bypass                     = var.network_rules.bypass
    ip_rules                   = var.network_rules.ip_rules
    virtual_network_subnet_ids = var.network_rules.virtual_network_subnet_ids
  }
}