resource "google_service_account" "buildingblock_storage_sa" {
  account_id   = var.service_account_id
  display_name = "Building Block Storage Service Account"
  description  = "Service account for storage bucket building block"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.buildingblock_storage_sa.email}"
}

resource "google_service_account_key" "buildingblock_storage_key" {
  service_account_id = google_service_account.buildingblock_storage_sa.name
}
