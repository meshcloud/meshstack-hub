output "replicator_token" {
  description = "Service account token meshStack uses to replicate namespaces onto the cluster. Empty when `output_to_vault` is set."
  value       = local.write_to_vault ? "" : local.replicator_token
  sensitive   = true
}

output "metering_token" {
  description = "Service account token meshStack uses to read metering data from the cluster. Empty when metering_enabled is false or `output_to_vault` is set."
  value       = local.write_to_vault ? "" : local.metering_token
  sensitive   = true
}

output "service_account_namespace" {
  description = "Namespace holding the replicator and metering service accounts."
  value       = module.namespace.name
}

output "replicator_service_account_name" {
  description = "Name of the replicator ServiceAccount, its ClusterRole and its ClusterRoleBinding, and prefix of its token Secrets."
  value       = local.replicator_name
}

output "metering_service_account_name" {
  description = "Name of the metering ServiceAccount and its companion resources. Null when metering_enabled is false."
  value       = var.metering_enabled ? local.metering_name : null
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret in Vault, where `secret_hash` changes with its content; `{}` without `output_to_vault`."
  value = {
    for key, value in {
      path        = local.vault_secret_path
      secret_hash = local.vault_secret_hash
    } : key => value if local.write_to_vault
  }
}
