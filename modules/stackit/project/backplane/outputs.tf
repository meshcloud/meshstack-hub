output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the service account used by the building block to create and manage projects."
}

output "service_account_key_json" {
  value       = stackit_service_account_key.building_block.json
  description = "Service account key JSON for authenticating the STACKIT provider in the buildingblock."
  sensitive   = true
}
