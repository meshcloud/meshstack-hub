output "namespace_name" {
  description = "Name of the created Kubernetes namespace."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "cluster_name" {
  description = "Name of the AKS cluster hosting the namespace."
  value       = var.aks_cluster_name
}

output "cluster_resource_group_name" {
  description = "Resource group of the AKS cluster hosting the namespace."
  value       = var.aks_resource_group_name
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # AKS namespace `${kubernetes_namespace_v1.this.metadata[0].name}`

    Created on cluster `${var.aks_cluster_name}` (resource group `${var.aks_resource_group_name}`).

    Fetch credentials with:

    ```
    az aks get-credentials --name ${var.aks_cluster_name} --resource-group ${var.aks_resource_group_name}
    kubectl config set-context --current --namespace ${kubernetes_namespace_v1.this.metadata[0].name}
    ```

    Quota: ${var.resource_quota.requests_cpu} CPU / ${var.resource_quota.requests_memory} requested,
    ${var.resource_quota.limits_cpu} CPU / ${var.resource_quota.limits_memory} limit, ${var.resource_quota.pods} pods.
  EOT
}
