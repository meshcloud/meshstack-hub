output "service_account_email" {
  description = "Email address of the backplane service account"
  value       = google_service_account.backplane.email
}

output "service_account_id" {
  description = "ID of the backplane service account"
  value       = google_service_account.backplane.id
}

output "credentials_json" {
  description = "The JSON credentials for the backplane service account"
  value       = base64decode(google_service_account_key.backplane.private_key)
  sensitive   = true
}

output "billing_account_id" {
  description = "The billing account ID where budget permissions were granted"
  value       = var.billing_account_id
}

output "backplane_project_id" {
  description = "The project hosting the building block backplane resources"
  value       = data.google_project.backplane.project_id
}