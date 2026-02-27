output "cluster_name" {
  description = "Name of the SKE cluster."
  value       = stackit_ske_cluster.this.name
}

output "kube_host" {
  description = "Kubernetes API server endpoint."
  value       = local.kube_host
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "PEM-encoded CA certificate for the cluster."
  value       = local.cluster_ca_certificate
  sensitive   = true
}

output "client_certificate" {
  description = "PEM-encoded client certificate for authentication."
  value       = local.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "PEM-encoded client key for authentication."
  value       = local.client_key
  sensitive   = true
}

output "replicator_token" {
  description = "Access token for the meshStack replicator service account."
  value       = module.meshplatform.replicator_token
  sensitive   = true
}

output "metering_token" {
  description = "Access token for the meshStack metering service account."
  value       = module.meshplatform.metering_token
  sensitive   = true
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster."
  value       = stackit_ske_cluster.this.kubernetes_version_used
}

output "console_url" {
  description = "URL to the STACKIT portal for this SKE cluster."
  value       = "https://portal.stackit.cloud/project/${stackit_ske_cluster.this.project_id}/kubernetes/${stackit_ske_cluster.this.name}"
}
