output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the service account used by the building block to manage spoke networks."
}
