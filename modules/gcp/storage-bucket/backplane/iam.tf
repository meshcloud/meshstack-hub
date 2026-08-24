resource "google_iam_workload_identity_pool" "meshstack" {
  # Nothing below references the APIs, so Terraform cannot infer this ordering on its own.
  depends_on = [google_project_service.required]

  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_federation.workload_identity_pool_identifier
  description               = "Identity pool for meshStack building blocks"
}

resource "google_iam_workload_identity_pool_provider" "meshstack" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.meshstack.workload_identity_pool_id
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

resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.buildingblock_storage_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack.name}/*"]
}

resource "google_project_iam_member" "storage_admin" {
  depends_on = [google_project_service.required]

  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.buildingblock_storage_sa.email}"
}

# GCP IAM is eventually consistent. A building block run that starts right after these grants is
# denied, so hold the credentials output back until they take effect.
resource "time_sleep" "wait_for_iam" {
  depends_on = [
    google_service_account_iam_binding.workload_identity_binding,
    google_project_iam_member.storage_admin,
  ]

  create_duration = "${var.iam_propagation_delay_seconds}s"

  triggers = {
    workload_identity_members = join(",", google_service_account_iam_binding.workload_identity_binding.members)
    storage_admin_member      = google_project_iam_member.storage_admin.member
  }
}
