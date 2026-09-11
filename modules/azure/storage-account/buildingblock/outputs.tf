output "storage_account_id" {
  value = azurerm_storage_account.storage_account.id
}

output "storage_account_name" {
  value = azurerm_storage_account.storage_account.name
}

output "storage_account_resource_group" {
  value = azurerm_resource_group.storage_account_rg.name
}

output "storage_account_url" {
  value = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${azurerm_storage_account.storage_account.id}/overview"
}

output "account_replication_type" {
  value = azurerm_storage_account.storage_account.account_replication_type
}

output "tags" {
  value = azurerm_storage_account.storage_account.tags
}

output "network_default_action" {
  value = azurerm_storage_account.storage_account.network_rules[0].default_action
}

output "blob_soft_delete_retention_days" {
  # `try` so that a storage account created without a blob_properties.delete_retention_policy block
  # (blob_soft_delete_retention_days left unset) reports null instead of failing on the missing index.
  value = try(azurerm_storage_account.storage_account.blob_properties[0].delete_retention_policy[0].days, null)
}
