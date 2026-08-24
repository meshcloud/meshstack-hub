data "google_project" "backplane" {
  project_id = var.backplane_project_id
}

resource "google_service_account" "backplane" {
  depends_on = [google_project_service.required]

  project      = data.google_project.backplane.project_id
  account_id   = var.backplane_service_account_name
  display_name = var.backplane_service_account_name
}

# Grant billing account permissions to create budgets
resource "google_billing_account_iam_member" "budget_admin" {
  depends_on = [google_project_service.required]

  billing_account_id = var.billing_account_id
  role               = "roles/billing.costsManager"
  member             = "serviceAccount:${google_service_account.backplane.email}"
}

# Additional permission to view billing data
resource "google_billing_account_iam_member" "billing_viewer" {
  depends_on = [google_project_service.required]

  billing_account_id = var.billing_account_id
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${google_service_account.backplane.email}"
}

resource "google_service_account_key" "backplane" {
  service_account_id = google_service_account.backplane.name
}

resource "google_project_iam_member" "notification_channel_admin" {
  depends_on = [google_project_service.required]

  project = data.google_project.backplane.project_id
  role    = "roles/monitoring.notificationChannelEditor"
  member  = "serviceAccount:${google_service_account.backplane.email}"
}

# `disable_on_destroy = false` is deliberate and load-bearing: destroying this backplane must not
# switch a project-wide API off. A backplane never owns its project exclusively and can be
# short-lived (an ephemeral backplane in an e2e test is provisioned and torn down per run), so
# disabling one of these on teardown would break every other tenant of the same project.
# `disable_dependent_services = false` closes the same failure mode one level out: it stops a
# destroy from cascading into services that merely depend on one of these.
resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",                  # the service account and its key
    "cloudresourcemanager.googleapis.com", # the project-level IAM binding
    "cloudbilling.googleapis.com",         # the billing account IAM bindings, billed to this project as quota project
    "billingbudgets.googleapis.com",       # google_billing_budget, at building block run time
    "monitoring.googleapis.com",           # google_monitoring_notification_channel, at building block run time
  ])

  project                    = data.google_project.backplane.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

moved {
  from = google_project_service.billingbudgets
  to   = google_project_service.required["billingbudgets.googleapis.com"]
}

# GCP IAM is eventually consistent, and billing-account grants are among the slower ones. A
# building block run that starts right after these grants is denied, so hold the credentials output
# back until they take effect.
resource "time_sleep" "wait_for_iam" {
  depends_on = [
    google_billing_account_iam_member.budget_admin,
    google_billing_account_iam_member.billing_viewer,
    google_project_iam_member.notification_channel_admin,
  ]

  create_duration = "${var.iam_propagation_delay_seconds}s"

  triggers = {
    member = google_service_account.backplane.email
  }
}
