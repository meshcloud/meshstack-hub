locals {
  # Deliberately assembled from the provider's own identifiers rather than read off
  # google_iam_workload_identity_pool_provider.meshstack.name, to keep the credentials output free of
  # any dependency on the pool provider — the one resource that consumes
  # var.workload_identity_subjects. Those subjects name the building block definition, the definition
  # carries these credentials, and reading the attribute back would close that loop into a cycle.
  # The format is the documented resource name of a pool provider.
  workload_identity_pool_provider_name = "projects/${data.google_project.backplane.number}/locations/global/workloadIdentityPools/${var.workload_identity_federation.workload_identity_pool_identifier}/providers/${var.workload_identity_federation.workload_identity_pool_identifier}"
}

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

  description = "External account credentials the building block authenticates with. Points the runner at its own OIDC token file, which it exchanges for a short-lived access token."
  sensitive   = true
  value = jsonencode({
    universe_domain                   = "googleapis.com"
    type                              = "external_account"
    audience                          = "//iam.googleapis.com/${local.workload_identity_pool_provider_name}"
    subject_token_type                = "urn:ietf:params:oauth:token-type:jwt"
    token_url                         = "https://sts.googleapis.com/v1/token"
    service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.backplane.email}:generateAccessToken"
    credential_source = {
      file = var.workload_identity_federation.subject_token_file_path
    }
  })
}

output "billing_account_id" {
  description = "The billing account ID where budget permissions were granted"
  value       = var.billing_account_id
}

output "backplane_project_id" {
  description = "The project hosting the building block backplane resources"
  value       = data.google_project.backplane.project_id
}
