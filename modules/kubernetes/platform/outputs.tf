output "replicator_token" {
  description = "Service account token meshStack uses to replicate namespaces onto the cluster."
  value       = local.replicator_token
  sensitive   = true
}

output "metering_token" {
  description = "Service account token meshStack uses to read metering data from the cluster. Null when metering_enabled is false."
  value       = local.metering_token
  sensitive   = true
}

output "service_account_namespace" {
  description = "Namespace holding the replicator and metering service accounts."
  value       = kubernetes_namespace_v1.meshcloud.metadata[0].name
}

output "replicator_service_account_name" {
  description = "Name of the replicator ServiceAccount, its token Secret, its ClusterRole and its ClusterRoleBinding — all four share it."
  value       = local.replicator_name
}

output "metering_service_account_name" {
  description = "Name of the metering ServiceAccount and its companion resources. Null when metering_enabled is false."
  value       = var.metering_enabled ? local.metering_name : null
}
