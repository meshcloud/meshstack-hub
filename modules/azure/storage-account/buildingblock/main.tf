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

  network_rules = jsondecode(var.network_rules)
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "${var.storage_account_name}${random_string.resource_code.result}"
  resource_group_name      = azurerm_resource_group.storage_account_rg.name
  location                 = azurerm_resource_group.storage_account_rg.location
  account_tier             = var.account_tier
  account_replication_type = local.effective_replication_type

  tags = var.business_unit != null ? { BusinessUnit = join(",", var.business_unit) } : {}

  dynamic "blob_properties" {
    for_each = var.blob_soft_delete_retention_days != null ? [1] : []
    content {
      delete_retention_policy {
        days = var.blob_soft_delete_retention_days
      }
    }
  }

  network_rules {
    default_action = local.network_rules.default_action

    # `try` so that a Network Rules value which only sets default_action (bypass/ip_rules/
    # virtual_network_subnet_ids are optional in the json_schema) falls back to Azure's own
    # defaults instead of failing on a missing key.
    bypass                     = try(local.network_rules.bypass, ["AzureServices"])
    ip_rules                   = try(local.network_rules.ip_rules, [])
    virtual_network_subnet_ids = try(local.network_rules.virtual_network_subnet_ids, [])
  }
}