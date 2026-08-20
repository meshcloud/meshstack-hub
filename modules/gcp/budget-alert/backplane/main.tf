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

# The Cloud Billing Budget API backs the `google_billing_budget` the building block creates. The
# service account the building block runs as lives in this project, so this project is the quota
# project for those calls and the API has to be on here.
#
# `disable_on_destroy = false` is deliberate and load-bearing: destroying this backplane must not
# switch a project-wide API off. A backplane never owns its project exclusively and can be
# short-lived (an ephemeral backplane in a test harness is provisioned and torn down per run), so
# disabling `billingbudgets.googleapis.com` on teardown would break every other tenant of the same
# project. `disable_dependent_services = false` is set for the same reason, one level out: it stops
# a destroy from cascading into services that merely depend on this one.
resource "google_project_service" "billingbudgets" {
  project                    = data.google_project.backplane.project_id
  service                    = "billingbudgets.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}
