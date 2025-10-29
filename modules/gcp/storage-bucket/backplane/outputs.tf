output "credentials_json" {
  sensitive = true
  value = var.workload_identity_federation == null ? (
    base64decode(google_service_account_key.buildingblock_storage_key[0].private_key)
    ) : (
    jsonencode({
      universe_domain                   = "googleapis.com"
      type                              = "external_account"
      audience                          = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.meshstack[0].name}"
      subject_token_type                = "urn:ietf:params:oauth:token-type:jwt"
      token_url                         = "https://sts.googleapis.com/v1/token"
      service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.buildingblock_storage_sa.email}:generateAccessToken"
      credential_source = {
        file = var.workload_identity_federation.subject_token_file_path
      }
    })
  )
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.buildingblock_storage_sa.email
}

output "workload_identity_pool_name" {
  description = "Name of the workload identity pool"
  value       = var.workload_identity_federation != null ? google_iam_workload_identity_pool.meshstack[0].name : null
}

output "workload_identity_provider_name" {
  description = "Name of the workload identity provider"
  value       = var.workload_identity_federation != null ? google_iam_workload_identity_pool_provider.meshstack[0].name : null
}
