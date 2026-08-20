resource "google_iam_workload_identity_pool" "meshstack" {
  count = var.workload_identity_federation == null ? 0 : 1

  # Nothing here references google_project_service, so without this the pool can be created before
  # iam.googleapis.com is enabled and fail with SERVICE_DISABLED.
  depends_on = [google_project_service.required]

  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_federation.workload_identity_pool_identifier
  description               = "Identity pool for meshStack building blocks"
}

resource "google_iam_workload_identity_pool_provider" "meshstack" {
  count = var.workload_identity_federation == null ? 0 : 1

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.meshstack[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_federation.workload_identity_pool_identifier

  description = "OIDC identity provider for meshStack building blocks"

  oidc {
    issuer_uri        = var.workload_identity_federation.issuer
    allowed_audiences = [var.workload_identity_federation.audience]
  }

  # Map the OIDC token's `sub` claim to google.subject
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  # Restrict token acceptance to configured subjects
  attribute_condition = join(" || ", [
    for subject in var.workload_identity_federation.subjects :
    "google.subject.startsWith('${subject}')"
  ])
}

resource "google_service_account" "buildingblock_storage_sa" {
  depends_on = [google_project_service.required]

  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Building Block Storage Service Account"
  description  = "Service account for storage bucket building block"
}

# GCP IAM is eventually consistent: Google's workload identity federation troubleshooting guidance
# is to wait two to seven minutes after adding a `roles/iam.workloadIdentityUser` binding before
# retrying. Until it lands, the meshStack building block runner completes the STS token exchange —
# which proves the pool, provider, attribute mapping and attribute condition are all correct — and
# is then refused at the impersonation step:
#
# > Error: Post "https://storage.googleapis.com/storage/v1/b?...&project=...":
# > oauth2/google: status code 403: Permission 'iam.serviceAccounts.getAccessToken' denied on
# > resource (or it may not exist). ... "reason": "IAM_PERMISSION_DENIED"
#
# See time_sleep.wait_for_iam below, which the credentials output depends on so that any consumer
# building a building block definition from them is ordered after the wait automatically.
resource "google_service_account_iam_binding" "workload_identity_binding" {
  count = var.workload_identity_federation == null ? 0 : 1

  service_account_id = google_service_account.buildingblock_storage_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack[0].name}/*"]
}

resource "google_project_iam_member" "storage_admin" {
  depends_on = [google_project_service.required]

  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.buildingblock_storage_sa.email}"
}

# Wait for the grants above to become effective before anything uses them. Both are needed by a
# building block run — `workloadIdentityUser` to impersonate the service account, `storage.admin` to
# create the bucket once impersonated — and both are subject to it.
resource "time_sleep" "wait_for_iam" {
  depends_on = [
    google_service_account_iam_binding.workload_identity_binding,
    google_project_iam_member.storage_admin,
  ]

  create_duration = "${var.iam_propagation_delay_seconds}s"

  # Re-wait when a grant actually changes, rather than only on first create. Deliberately not the
  # bindings' etags, which churn on unrelated edits to the same policy.
  triggers = {
    workload_identity_members = join(",", flatten([
      for binding in google_service_account_iam_binding.workload_identity_binding : binding.members
    ]))
    storage_admin_member = google_project_iam_member.storage_admin.member
  }
}

resource "google_service_account_key" "buildingblock_storage_key" {
  count = var.workload_identity_federation == null ? 1 : 0

  service_account_id = google_service_account.buildingblock_storage_sa.name
}
