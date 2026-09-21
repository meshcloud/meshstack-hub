output "cluster_name" {
  description = "Name of the SKE cluster."
  value       = stackit_ske_cluster.this.name
}

output "cluster_url" {
  description = "Deep link to the STACKIT project the cluster lives in, in the STACKIT portal."
  value       = "https://portal.stackit.cloud/projects/${var.stackit_project_id}/ske/clusters"
}

output "kube_host" {
  description = "Kubernetes API server URL of the cluster."
  # The server URL is derived from the (sensitive) kubeconfig but is not itself a secret — it is the
  # public API endpoint, consumed as the meshStack platform endpoint and the kubernetes/helm host.
  value = nonsensitive(local.kubeconfig_cluster.server)
}

# Raw kubeconfig, consumed by a composing architecture to configure its kubernetes/helm providers and
# to hand cluster access to downstream building blocks (e.g. the Forgejo connector). It carries
# cluster-admin credentials, so it is sensitive; a composition passes it on rather than displaying it.
output "kubeconfig" {
  description = "Raw kubeconfig content for cluster access."
  value       = stackit_ske_kubeconfig.this.kube_config
  sensitive   = true
}

output "provider_config" {
  description = "Decoded kubeconfig values for wiring a kubernetes/helm provider without re-parsing the raw kubeconfig."
  value = {
    host                   = local.kubeconfig_cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig_cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig_admin_user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig_admin_user["client-key-data"])
  }
  sensitive = true
}
