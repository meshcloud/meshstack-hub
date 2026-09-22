output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the STACKIT service account used by the buildingblock provider via WIF."
}
