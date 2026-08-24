output "credentials_json" {
  # A consumer embeds these credentials in a building block definition and can order a building
  # block seconds later. Waiting here orders that consumer after the wait without it knowing.
  depends_on = [time_sleep.wait_for_iam]

  description = "External account credentials for the building block's service account. Contains no long-lived secret — it points the runner at its own token file."
  sensitive   = true
  value = jsonencode({
    universe_domain                   = "googleapis.com"
    type                              = "external_account"
    audience                          = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.meshstack.name}"
    subject_token_type                = "urn:ietf:params:oauth:token-type:jwt"
    token_url                         = "https://sts.googleapis.com/v1/token"
    service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.buildingblock_storage_sa.email}:generateAccessToken"
    credential_source = {
      file = var.workload_identity_federation.subject_token_file_path
    }
  })
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.buildingblock_storage_sa.email
}

output "workload_identity_pool_name" {
  description = "Name of the workload identity pool"
  value       = google_iam_workload_identity_pool.meshstack.name
}

output "workload_identity_provider_name" {
  description = "Name of the workload identity provider"
  value       = google_iam_workload_identity_pool_provider.meshstack.name
}
