output "service_account_email" {
  value       = var.service_account_email
  description = "Email of the federated service account. Children of this block authenticate as it."
}

locals {
  service_account_url = "https://portal.stackit.cloud/service-accounts/${var.service_account_email}/overview?project=${var.project_id}"
}

output "service_account_url" {
  value       = local.service_account_url
  description = "STACKIT portal page of the federated service account."
}

output "summary" {
  description = "Summary of the federation."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    service_account_email = var.service_account_email
    service_account_url   = local.service_account_url
    definitions           = var.federated_building_block_definitions
  })
}
