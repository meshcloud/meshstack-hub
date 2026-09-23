output "service_account_email" {
  value       = var.service_account_email
  description = "Email of the federated service account. Children of this block authenticate as it."
}

output "summary" {
  description = "Summary of the federation."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    service_account_email = var.service_account_email
    project_id            = var.project_id
    definitions           = var.federated_building_block_definitions
  })
}
