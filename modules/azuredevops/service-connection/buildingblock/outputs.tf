output "service_connection_id" {
  description = "ID of the created service connection"
  value       = azuredevops_serviceendpoint_azurerm.main.id
}

output "service_connection_name" {
  description = "Name of the created service connection"
  value       = azuredevops_serviceendpoint_azurerm.main.service_endpoint_name
}

output "service_principal_id" {
  description = "Client ID of the service principal"
  value       = azuread_service_principal.service_connection.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal"
  value       = azuread_service_principal.service_connection.object_id
}

output "azure_subscription_id" {
  description = "Azure Subscription ID connected"
  value       = data.azurerm_subscription.target.subscription_id
}

output "azure_subscription_name" {
  description = "Azure Subscription name connected"
  value       = data.azurerm_subscription.target.display_name
}

output "azure_role" {
  description = "Azure role assigned to the service principal"
  value       = var.azure_role
}

output "authorized_all_pipelines" {
  description = "Whether all pipelines are authorized to use this connection"
  value       = var.authorize_all_pipelines
}
