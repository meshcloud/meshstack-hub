output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "Azure resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "resource_group_name" {
  description = "Resource group holding the AKS cluster"
  value       = azurerm_resource_group.aks.name
}

output "kube_api_server_fqdn" {
  description = "FQDN of the Kubernetes API server, the private one for a private cluster"
  value       = var.private_cluster_enabled ? azurerm_kubernetes_cluster.aks.private_fqdn : azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_portal_url" {
  description = "Azure Portal URL of the AKS cluster"
  value       = local.portal_url
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
  value       = length(azurerm_log_analytics_workspace.law) > 0 ? azurerm_log_analytics_workspace.law[0].id : null
}

output "subnet_id" {
  description = "Subnet ID used by AKS"
  value       = local.subnet_id
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # AKS cluster `${azurerm_kubernetes_cluster.aks.name}`

    - **Resource group**: ${azurerm_resource_group.aks.name}
    - **Location**: ${azurerm_kubernetes_cluster.aks.location}
    - **Kubernetes version**: ${azurerm_kubernetes_cluster.aks.current_kubernetes_version}
    - **API server**: `${var.private_cluster_enabled ? azurerm_kubernetes_cluster.aks.private_fqdn : azurerm_kubernetes_cluster.aks.fqdn}`${var.private_cluster_enabled ? " (private)" : ""}
    - [Open in Azure Portal](${local.portal_url})

    Get credentials with `az aks get-credentials --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.aks.name}`.
  EOT
}
