output "service_principal_client_id" {
  description = "Client ID of the service principal for VMSS runner management"
  value       = azuread_application.vmss_runner.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal for VMSS runner management"
  value       = azuread_service_principal.vmss_runner.object_id
}

output "service_principal_client_secret" {
  description = "Client secret of the service principal for VMSS runner management"
  value       = azuread_service_principal_password.vmss_runner.value
  sensitive   = true
}

output "key_vault_id" {
  description = "ID of the Key Vault storing VMSS runner secrets"
  value       = azurerm_key_vault.vmss_runner.id
}

output "key_vault_name" {
  description = "Name of the Key Vault storing VMSS runner secrets"
  value       = azurerm_key_vault.vmss_runner.name
}

output "azuredevops_pat_secret_name" {
  description = "Name of the Azure DevOps PAT secret in Key Vault"
  value       = azurerm_key_vault_secret.azuredevops_pat.name
}
