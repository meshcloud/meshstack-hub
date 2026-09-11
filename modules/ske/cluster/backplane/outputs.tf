output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the STACKIT service account the buildingblock provider authenticates as via WIF."
}
