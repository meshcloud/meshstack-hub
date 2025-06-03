data "google_project" "backplane" {
  project_id = var.backplane_project_id
}

resource "google_service_account" "backplane" {
  project      = data.google_project.backplane.project_id
  account_id   = var.backplane_service_account_name
  display_name = var.backplane_service_account_name
}

# Grant billing account permissions to create budgets
resource "google_billing_account_iam_member" "budget_admin" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.costsManager"
  member             = "serviceAccount:${google_service_account.backplane.email}"
}

# Additional permission to view billing data
resource "google_billing_account_iam_member" "billing_viewer" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${google_service_account.backplane.email}"
}

resource "google_service_account_key" "backplane" {
  service_account_id = google_service_account.backplane.name
}

resource "google_project_iam_member" "notification_channel_admin" {
  project = data.google_project.backplane.project_id
  role    = "roles/monitoring.notificationChannelEditor"
  member  = "serviceAccount:${google_service_account.backplane.email}"
}

resource "google_project_iam_member" "serviceusage_admin" {
  project = data.google_project.backplane.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.backplane.email}"
}

resource "google_project_service" "billingbudgets" {
  project = data.google_project.backplane.project_id
  service = "billingbudgets.googleapis.com"
}