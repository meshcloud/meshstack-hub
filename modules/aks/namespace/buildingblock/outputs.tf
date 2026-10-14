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

output "group_object_ids" {
  description = "Map of namespace role (admin, edit, view) to the object ID of the Entra group this block created."
  value       = local.created_group_object_ids
}

output "unresolved_users" {
  description = "Workspace members that have no matching object in the directory and were therefore not added to any group."
  value       = local.unresolved_user_euids
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

    ## Access

    | Namespace role | Entra group |
    |---|---|
    | `admin` | `${azuread_group.namespace["admin"].display_name}` |
    | `edit` | `${azuread_group.namespace["edit"].display_name}` |
    | `view` | `${azuread_group.namespace["view"].display_name}` |

    ${length(azuread_group_member.namespace)} membership(s) assigned from ${length(local.unique_user_euids)} workspace member(s), matched on `${var.user_lookup_attribute}`.${length(local.unresolved_user_euids) == 0 ? "" : " Not found in the directory and skipped: ${join(", ", local.unresolved_user_euids)}."}

    Quota: ${var.resource_quota.requests_cpu} CPU / ${var.resource_quota.requests_memory} requested,
    ${var.resource_quota.limits_cpu} CPU / ${var.resource_quota.limits_memory} limit, ${var.resource_quota.pods} pods.
  EOT
}
