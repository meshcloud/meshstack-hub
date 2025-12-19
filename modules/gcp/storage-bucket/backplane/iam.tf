resource "google_iam_workload_identity_pool" "meshstack" {
  count = var.workload_identity_federation == null ? 0 : 1

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
  account_id   = var.service_account_id
  display_name = "Building Block Storage Service Account"
  description  = "Service account for storage bucket building block"
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  count = var.workload_identity_federation == null ? 0 : 1

  service_account_id = google_service_account.buildingblock_storage_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack[0].name}/*"]
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.buildingblock_storage_sa.email}"
}

resource "google_service_account_key" "buildingblock_storage_key" {
  count = var.workload_identity_federation == null ? 1 : 0

  service_account_id = google_service_account.buildingblock_storage_sa.name
}
