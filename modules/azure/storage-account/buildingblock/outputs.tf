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
