output "service_account_email" {
  value       = stackit_service_account.backplane.email
  description = "Email of the service account used by the building block to manage spoke networks."
}

output "service_account_key_json" {
  value       = stackit_service_account_key.backplane.json
  description = "Service account key JSON for authenticating the STACKIT provider in the buildingblock."
  sensitive   = true
}
