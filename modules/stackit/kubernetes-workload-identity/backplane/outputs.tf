output "workload_service_account_email" {
  value       = stackit_service_account.workload.email
  description = "Email of the service account the Kubernetes workloads act as."
}

output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the service account the building block runs act as."
}
