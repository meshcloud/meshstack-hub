output "application_id" {
  description = "Application (client) ID of the Entra ID application"
  value       = azuread_application.main.client_id
}

output "application_object_id" {
  description = "Object ID of the Entra ID application"
  value       = azuread_application.main.object_id
}

output "service_principal_id" {
  description = "Client ID of the service principal (same as application_id)"
  value       = azuread_service_principal.main.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal"
  value       = azuread_service_principal.main.object_id
}

output "client_secret" {
  description = "Client secret for the service principal"
  value       = azuread_application_password.main.value
  sensitive   = true
}

output "tenant_id" {
  description = "Entra ID Tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Azure Subscription ID where role assignment was created"
  value       = data.azurerm_subscription.target.subscription_id
}

output "azure_role" {
  description = "Azure role assigned to the service principal"
  value       = var.azure_role
}

output "secret_expiration_date" {
  description = "Date when the service principal secret will expire"
  value       = azuread_application_password.main.end_date
}
