output "metering_service_account_email" {
  value       = stackit_service_account.metering.email
  description = "Email of the service account the metering CronJobs act as."
}

output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the service account the building block runs act as."
}
