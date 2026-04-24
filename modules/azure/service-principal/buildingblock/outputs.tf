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
  description = "Client secret for the service principal (null if create_client_secret is false)"
  value       = var.create_client_secret ? azuread_application_password.main[0].value : null
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

output "role_assignment_id" {
  description = "ID of the role assignment (null if no role was assigned)"
  value       = length(azurerm_role_assignment.main) > 0 ? azurerm_role_assignment.main[0].id : null
}

output "role_name" {
  description = "Name of the role assigned to the service principal (built-in or custom)"
  value       = var.custom_role != null ? var.custom_role.name : var.azure_role
}

output "custom_role_id" {
  description = "ID of the custom role definition (null if using built-in role)"
  value       = var.custom_role != null ? azurerm_role_definition.custom[0].role_definition_resource_id : null
}

output "custom_role" {
  description = "Custom role definition details (null if using built-in role)"
  value = var.custom_role != null ? {
    id          = azurerm_role_definition.custom[0].role_definition_resource_id
    name        = azurerm_role_definition.custom[0].name
    description = azurerm_role_definition.custom[0].description
    scope       = azurerm_role_definition.custom[0].scope
  } : null
}

output "secret_expiration_date" {
  description = "Date when the service principal secret will expire (null if create_client_secret is false)"
  value       = var.create_client_secret ? azuread_application_password.main[0].end_date : null
}

output "authentication_method" {
  description = "Authentication method for the service principal"
  value       = var.create_client_secret ? "client_secret" : "workload_identity_federation"
}
