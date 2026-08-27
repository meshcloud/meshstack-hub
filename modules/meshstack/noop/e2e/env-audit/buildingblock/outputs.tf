output "prerun_env_keys" {
  description = "JSON-encoded sorted list of environment variable names captured by the pre-run script."
  value       = data.external.prerun_env_keys.result.keys
}

output "apply_env_keys" {
  description = "JSON-encoded sorted list of environment variable names present during tofu apply."
  value       = data.external.apply_env_keys.result.keys
}
