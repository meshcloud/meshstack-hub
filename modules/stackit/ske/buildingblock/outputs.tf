output "cluster_name" {
  description = "Name of the SKE cluster."
  value       = stackit_ske_cluster.this.name
}

output "kube_host" {
  description = "URL of the Kubernetes API server. Feed this into the `kube_host` input of `modules/kubernetes/platform`."
  # The whole kubeconfig is sensitive because it carries the client certificate and key. The API
  # server URL is not a secret, so it is declassified here and a composition can pass it on as a
  # plain string.
  value = nonsensitive(local.kubeconfig_cluster.server)
}

output "kubeconfig" {
  description = "Raw kubeconfig content for cluster access."
  value       = local.kubeconfig
  sensitive   = true
}

output "provider_config" {
  description = "Kubernetes provider config values derived from the kubeconfig, for wiring a kubernetes or helm provider."
  value = {
    host                   = local.kubeconfig_cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig_cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig_admin_user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig_admin_user["client-key-data"])
  }
  sensitive = true
}
