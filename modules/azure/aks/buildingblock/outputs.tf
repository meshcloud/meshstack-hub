output "kube_config" {
  description = "Kubeconfig raw output"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for federated identity and workload identity setup"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "aks_identity_client_id" {
  description = "Client ID of the AKS system-assigned managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "law_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.law.id
}

output "subnet_id" {
  description = "Subnet ID used by AKS"
  value       = azurerm_subnet.aks_subnet.id
}
