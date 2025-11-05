output "service_principal_id" {
  description = "Application (client) ID of the service principal"
  value       = azuread_application.azure_devops.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal"
  value       = azuread_service_principal.azure_devops.object_id
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.devops.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.devops.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.devops.name
}

output "role_definition_id" {
  description = "ID of the custom role definition"
  value       = azurerm_role_definition.azure_devops_agent_pool_manager.id
}
