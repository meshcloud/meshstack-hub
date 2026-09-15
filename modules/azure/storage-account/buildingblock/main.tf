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
  copied_tags = var.tag_name != null && var.tag_value != null ? { (var.tag_name) = join(",", var.tag_value) } : {}
}

resource "azurerm_storage_account" "storage_account" {
  name                = "${var.storage_account_name}${random_string.resource_code.result}"
  resource_group_name = azurerm_resource_group.storage_account_rg.name
  location            = azurerm_resource_group.storage_account_rg.location

  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = local.copied_tags

  blob_properties {
    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }
  }

  dynamic "network_rules" {
    for_each = var.restrict_network_access ? [var.network_rules] : []
    content {
      default_action             = "Deny"
      bypass                     = network_rules.value.bypass
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
    }
  }
}
