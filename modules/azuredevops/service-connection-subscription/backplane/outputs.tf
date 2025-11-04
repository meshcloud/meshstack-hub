output "service_principal_client_id" {
  description = "Client ID of the Azure DevOps service principal"
  value       = azuread_service_principal.azure_devops.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the Azure DevOps service principal"
  value       = azuread_service_principal.azure_devops.object_id
}

output "key_vault_id" {
  description = "ID of the Key Vault for storing Azure DevOps PAT"
  value       = azurerm_key_vault.devops.id
}

output "key_vault_name" {
  description = "Name of the Key Vault for storing Azure DevOps PAT"
  value       = azurerm_key_vault.devops.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault for storing Azure DevOps PAT"
  value       = azurerm_key_vault.devops.vault_uri
}

output "resource_group_name" {
  description = "Name of the resource group containing the Key Vault"
  value       = azurerm_resource_group.devops.name
}

output "azure_devops_organization_url" {
  description = "Azure DevOps organization URL"
  value       = var.azure_devops_organization_url
}

output "application_id" {
  description = "Application (client) ID of the Azure AD application"
  value       = azuread_application.azure_devops.client_id
}
