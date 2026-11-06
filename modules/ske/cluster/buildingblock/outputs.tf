output "cluster_name" {
  description = "Name of the SKE cluster."
  value       = module.cluster.cluster.name
}

output "kube_host" {
  description = "Kubernetes API server URL of the cluster."
  value       = terraform_data.kube_host.output
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret in Vault, where `secret_hash` changes with its content."
  value = {
    path        = local.vault_secret_path
    secret_hash = local.vault_secret_hash
  }
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value       = <<-EOT
    # SKE Cluster: **${module.cluster.cluster.name}**

    | Property | Value |
    |----------|-------|
    | **Cluster** | <a href="https://portal.stackit.cloud/kubernetes/clusters/details/${module.cluster.cluster.name}/overview?project=${var.stackit_project_id}" target="_blank" rel="noopener">Open in STACKIT Portal</a> |
    | **Kubernetes** | `${module.cluster.cluster.kubernetes_version_used}` |
    | **API Server** | `${terraform_data.kube_host.output}` |
    | **Node Pool** | `${var.node_pool.name}`: ${var.node_pool.minimum} to ${var.node_pool.maximum} × `${var.node_pool.machine_type}` in ${join(", ", var.node_pool.availability_zones)} |
    | **Maintenance** | daily `${var.maintenance.start}` to `${var.maintenance.end}` |

    ## Platform admin kubeconfig

    The service account `kube-system/${local.admin_name}` is bound to `cluster-admin`. Its kubeconfig is
    the key `kubeconfig` of the Vault secret `${local.vault_secret_path}` on mount `${local.vault_mount}`.
    The token belongs to generation `${var.admin_token_generation}`; the one of the month before stays valid.

    ```sh
    export VAULT_ADDR=${local.vault_address}
    export VAULT_TOKEN=$(stackit auth get-access-token)
    vault kv get -mount=${local.vault_mount} -field=kubeconfig ${local.vault_secret_path} > kubeconfig
    ```

    For your own access, STACKIT issues a kubeconfig that expires:

    ```sh
    stackit ske kubeconfig create ${module.cluster.cluster.name} --project-id ${var.stackit_project_id}
    ```
  EOT
}
