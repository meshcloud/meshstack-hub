output "service_account_email" {
  value       = stackit_service_account.this.email
  description = "Email of the created STACKIT service account. Use it as the principal in external federation configs and STACKIT role assignments."
}

output "service_account_url" {
  value       = "https://portal.stackit.cloud/projects/${var.project_id}/service-accounts"
  description = "Deep link to the service accounts overview of the project in the STACKIT portal."
}

output "summary" {
  description = "Summary of the created service account."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    service_account_name  = stackit_service_account.this.name
    service_account_email = stackit_service_account.this.email
    roles                 = var.roles
    federation_count      = length(var.federated_identities)
    project_id            = var.project_id
  })
}
