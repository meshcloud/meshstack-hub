output "credentials_json" {
  # A consumer embeds these credentials in a building block definition and can order a building
  # block seconds later. Waiting here orders that consumer after the wait without it knowing.
  depends_on = [time_sleep.wait_for_iam]

  description = "External account credentials for the building block's service account. Points the runner at its own OIDC token file, which it exchanges for a short-lived access token."
  sensitive   = true
  value = jsonencode({
    universe_domain = "googleapis.com"
    type            = "external_account"
    # Built rather than read off google_iam_workload_identity_pool_provider.meshstack, whose
    # attribute_condition names the definition that consumes this output. The name is deterministic.
    audience                          = "//iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.workload_identity_federation.workload_identity_pool_identifier}/providers/${var.workload_identity_federation.workload_identity_pool_identifier}"
    subject_token_type                = "urn:ietf:params:oauth:token-type:jwt"
    token_url                         = "https://sts.googleapis.com/v1/token"
    service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.buildingblock.email}:generateAccessToken"
    credential_source = {
      file = var.workload_identity_federation.subject_token_file_path
    }
  })
}

output "service_account_email" {
  description = "Email of the service account the building block runs as."
  value       = google_service_account.buildingblock.email
}

output "forbidden_namespaces" {
  # Orders a consumer's building block definition after the building block can grant access.
  depends_on = [kubernetes_cluster_role_binding_v1.grant_access]

  description = "Namespaces the building block can't grant access to. A trailing `*` matches a prefix."
  value       = local.forbidden_namespaces
}

output "cluster_role" {
  description = "ClusterRole the building block binds developers to."
  value       = var.cluster_role
}

output "binding_label" {
  description = "Label the building block sets on each RoleBinding it creates, so the cleanup CronJob finds it."
  value       = local.binding_label
}

output "expiry_annotation" {
  description = "Annotation the building block sets to the RoleBinding's expiry, in UTC RFC 3339 (`YYYY-MM-DDTHH:MM:SSZ`)."
  value       = local.expiry_annotation
}
