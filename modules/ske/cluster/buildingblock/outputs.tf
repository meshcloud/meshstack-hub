output "cluster_name" {
  description = "Name of the SKE cluster."
  value       = module.cluster.cluster.name
}

output "cluster_url" {
  description = "Deep link to the STACKIT project the cluster lives in, in the STACKIT portal."
  value       = "https://portal.stackit.cloud/projects/${var.stackit_project_id}/ske/clusters"
}

output "kube_host" {
  description = "Kubernetes API server URL of the cluster."
  value       = terraform_data.kube_host.output
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret written to `output_to_vault`. `secret_hash` is the secret's KV version and changes with its content."
  value = {
    path        = local.vault_secret_path
    secret_hash = local.vault_secret_hash
  }
}
