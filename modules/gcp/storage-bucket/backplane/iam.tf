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
    allowed_audiences = [var.workload_identity_federation.audience]
    issuer_uri        = var.workload_identity_federation.issuer
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  attribute_condition = "google.subject == '${var.workload_identity_federation.subject}'"
}

resource "google_service_account" "buildingblock_storage_sa" {
  account_id   = var.service_account_id
  display_name = "Building Block Storage Service Account"
  description  = "Service account for storage bucket building block"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  count = var.workload_identity_federation == null ? 0 : 1

  service_account_id = google_service_account.buildingblock_storage_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack[0].name}/subject/${var.workload_identity_federation.subject}"
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
