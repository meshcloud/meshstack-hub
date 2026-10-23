data "google_project" "this" {
  project_id = var.project_id
}

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
    issuer_uri        = var.workload_identity_federation_trust.issuer
    allowed_audiences = [var.workload_identity_federation_trust.audience]
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  attribute_condition = join(" || ", [
    for subject in var.workload_identity_federation_trust.subjects :
    "google.subject == '${subject}'"
  ])
}

resource "google_service_account" "buildingblock" {
  depends_on = [google_project_service.required]

  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "GKE Temporary Access Building Block"
  description  = "Grants developers time-limited read access to GKE namespaces"
}

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.buildingblock.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack.name}/*"]
}

# GKE only lets an identity authenticate if it holds container.clusters.get. The building block
# needs that itself to manage RoleBindings, and RBAC decides what it may do inside the cluster.
resource "google_project_iam_member" "cluster_viewer" {
  depends_on = [google_project_service.required]

  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${google_service_account.buildingblock.email}"
}

# The building block grants developers a time-limited roles/container.clusterViewer. Without the
# condition, projectIamAdmin would let this tenant-facing identity grant any role on the project.
resource "google_project_iam_member" "grant_cluster_viewer" {
  depends_on = [google_project_service.required]

  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.buildingblock.email}"

  condition {
    title       = "only-grant-cluster-viewer"
    description = "May only add or remove grants of roles/container.clusterViewer"
    expression  = "api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', []).hasOnly(['roles/container.clusterViewer'])"
  }
}

# GCP IAM is eventually consistent. A building block run that starts right after these grants is
# denied, so hold the credentials output back until they take effect.
resource "time_sleep" "wait_for_iam" {
  depends_on = [
    google_service_account_iam_binding.workload_identity,
    google_project_iam_member.cluster_viewer,
    google_project_iam_member.grant_cluster_viewer,
  ]

  create_duration = "${var.iam_propagation_delay_seconds}s"

  triggers = {
    workload_identity_members   = join(",", google_service_account_iam_binding.workload_identity.members)
    cluster_viewer_member       = google_project_iam_member.cluster_viewer.member
    grant_cluster_viewer_member = google_project_iam_member.grant_cluster_viewer.member
  }
}
