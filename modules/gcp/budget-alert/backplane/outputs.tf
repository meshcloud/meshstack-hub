output "service_account_email" {
  description = "Email address of the backplane service account"
  value       = google_service_account.backplane.email
}

output "service_account_id" {
  description = "ID of the backplane service account"
  value       = google_service_account.backplane.id
}

output "credentials_json" {
  # A consumer embeds these credentials in a building block definition and can order a building
  # block seconds later. Waiting here orders that consumer after the wait without it knowing.
  depends_on = [time_sleep.wait_for_iam]

  description = "Credentials for the backplane service account: an external account document on the federated path, the decoded key otherwise"
  sensitive   = true
  value = var.workload_identity_federation == null ? (
    base64decode(google_service_account_key.backplane[0].private_key)
    ) : (
    jsonencode({
      universe_domain                   = "googleapis.com"
      type                              = "external_account"
      audience                          = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.meshstack[0].name}"
      subject_token_type                = "urn:ietf:params:oauth:token-type:jwt"
      token_url                         = "https://sts.googleapis.com/v1/token"
      service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.backplane.email}:generateAccessToken"
      credential_source = {
        file = var.workload_identity_federation.subject_token_file_path
      }
    })
  )
}

output "billing_account_id" {
  description = "The billing account ID where budget permissions were granted"
  value       = var.billing_account_id
}

output "backplane_project_id" {
  description = "The project hosting the building block backplane resources"
  value       = data.google_project.backplane.project_id
}