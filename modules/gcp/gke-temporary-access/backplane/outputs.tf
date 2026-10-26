output "credentials_json" {
  description = "Credentials for the building block's service account. Points the runner at its own OIDC token file, which it exchanges for a short-lived access token."
  sensitive   = true
  value = jsonencode({
    universe_domain = "googleapis.com"
    type            = "external_account"
    # Build the audience locally to avoid a dependency cycle through the definition's trust settings.
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
  # Output after the restriction is in place.
  depends_on = [kubernetes_cluster_role_binding_v1.grant_access]

  description = "Namespaces the building block can't grant access to. A trailing `*` matches a prefix."
  value       = local.forbidden_namespaces
}

output "cluster_role" {
  description = "ClusterRole the building block binds developers to."
  value       = var.cluster_role
}

output "binding_label" {
  description = "Label key used to identify managed RoleBindings. The building block sets its value to `true`."
  value       = local.binding_label
}

output "expiry_annotation" {
  description = "Annotation key used to store the RoleBinding's expiry timestamp in RFC 3339 format (UTC, `YYYY-MM-DDTHH:MM:SSZ`)."
  value       = local.expiry_annotation
}
