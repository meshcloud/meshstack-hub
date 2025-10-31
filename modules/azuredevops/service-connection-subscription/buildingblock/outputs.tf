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
  value       = var.service_principal_id
}

output "azure_subscription_id" {
  description = "Azure Subscription ID connected"
  value       = data.azurerm_subscription.target.subscription_id
}

output "azure_subscription_name" {
  description = "Azure Subscription name connected"
  value       = data.azurerm_subscription.target.display_name
}

output "authorized_all_pipelines" {
  description = "Whether all pipelines are authorized to use this connection"
  value       = var.authorize_all_pipelines
}

output "authentication_method" {
  description = "Authentication method used"
  value       = "workload_identity_federation"
}

output "workload_identity_federation_issuer" {
  description = "Issuer URL for workload identity federation"
  value       = azuredevops_serviceendpoint_azurerm.main.workload_identity_federation_issuer
}

output "workload_identity_federation_subject" {
  description = "Subject identifier for workload identity federation"
  value       = azuredevops_serviceendpoint_azurerm.main.workload_identity_federation_subject
}
