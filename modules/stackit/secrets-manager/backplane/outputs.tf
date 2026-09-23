output "project_id" {
  value       = var.project_id
  description = "STACKIT project ID for Secrets Manager instance creation."
}

output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the STACKIT service account used by the buildingblock provider via WIF."
}
