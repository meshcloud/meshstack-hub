data "google_project" "backplane" {
  project_id = var.backplane_project_id
}

resource "google_service_account" "backplane" {
  depends_on = [google_project_service.required]

  project      = data.google_project.backplane.project_id
  account_id   = var.backplane_service_account_name
  display_name = var.backplane_service_account_name
}

resource "google_iam_workload_identity_pool" "meshstack" {
  count = var.workload_identity_federation == null ? 0 : 1

  depends_on = [google_project_service.required]

  project                   = data.google_project.backplane.project_id
  workload_identity_pool_id = var.workload_identity_federation.workload_identity_pool_identifier
  description               = "Identity pool for meshStack building blocks"
}

resource "google_iam_workload_identity_pool_provider" "meshstack" {
  count = var.workload_identity_federation == null ? 0 : 1

  project                            = data.google_project.backplane.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.meshstack[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_federation.workload_identity_pool_identifier

  description = "OIDC identity provider for meshStack building blocks"

  oidc {
    issuer_uri        = var.workload_identity_federation.issuer
    allowed_audiences = [var.workload_identity_federation.audience]
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  attribute_condition = join(" || ", [
    for subject in var.workload_identity_federation.subjects :
    "google.subject.startsWith('${subject}')"
  ])
}

resource "google_service_account_iam_binding" "workload_identity" {
  count = var.workload_identity_federation == null ? 0 : 1

  service_account_id = google_service_account.backplane.name
  role               = "roles/iam.workloadIdentityUser"
  members            = ["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack[0].name}/*"]
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

resource "google_project_iam_member" "notification_channel_admin" {
  depends_on = [google_project_service.required]

  project = data.google_project.backplane.project_id
  role    = "roles/monitoring.notificationChannelEditor"
  member  = "serviceAccount:${google_service_account.backplane.email}"
}

# Legacy credential path, kept for consumers that have not moved to workload identity federation.
# Creating one needs roles/iam.serviceAccountKeyAdmin, which roles/iam.serviceAccountAdmin does not
# include — so a caller on the federated path needs strictly fewer privileges than one on this path.
resource "google_service_account_key" "backplane" {
  count = var.workload_identity_federation == null ? 1 : 0

  service_account_id = google_service_account.backplane.name
}

# `disable_on_destroy = false` is deliberate and load-bearing: destroying this backplane must not
# switch a project-wide API off. A backplane never owns its project exclusively and can be
# short-lived (an ephemeral backplane in an e2e test is provisioned and torn down per run), so
# disabling one of these on teardown would break every other tenant of the same project.
# `disable_dependent_services = false` closes the same failure mode one level out: it stops a
# destroy from cascading into services that merely depend on one of these.
resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",                  # the service account, the pool and its provider
    "cloudresourcemanager.googleapis.com", # the project-level IAM binding
    "cloudbilling.googleapis.com",         # the billing account IAM bindings, billed to this project as quota project
    "sts.googleapis.com",                  # federated token exchange at building block run time
    "iamcredentials.googleapis.com",       # service account impersonation at run time
    "billingbudgets.googleapis.com",       # google_billing_budget, at run time
    "monitoring.googleapis.com",           # google_monitoring_notification_channel, at run time
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
    google_service_account_iam_binding.workload_identity,
  ]

  create_duration = "${var.iam_propagation_delay_seconds}s"

  triggers = {
    member = google_service_account.backplane.email
  }
}
