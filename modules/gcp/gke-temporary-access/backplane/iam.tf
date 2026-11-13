data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pool_identifier      = var.workload_identity_federation.workload_identity_pool_identifier
  current_runner_uuid  = coalesce(var.workload_identity_federation.runner_uuid, "current")
  original_runner_uuid = coalesce(var.workload_identity_federation.original_runner_uuid, local.current_runner_uuid)
  current_provider_id  = local.current_runner_uuid == local.original_runner_uuid ? local.pool_identifier : "runner-${substr(local.current_runner_uuid, 0, 8)}"

  runner_trusts = merge(
    {
      for identity in var.trusted_runner_identities : identity.runner_uuid => {
        issuer   = identity.issuer
        audience = identity.audience
        subjects = identity.subject == null ? [] : [identity.subject]
      }
    },
    {
      (local.current_runner_uuid) = {
        issuer   = var.workload_identity_federation_trust.issuer
        audience = var.workload_identity_federation_trust.audience
        subjects = var.workload_identity_federation_trust.subjects
      }
    },
  )

  original_runner_trust = contains(keys(local.runner_trusts), local.original_runner_uuid) ? local.runner_trusts[local.original_runner_uuid] : null
  other_runner_trusts   = { for uuid, trust in local.runner_trusts : uuid => trust if uuid != local.original_runner_uuid }
}

resource "google_iam_workload_identity_pool" "meshstack" {
  depends_on = [google_project_service.required]

  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_federation.workload_identity_pool_identifier
  description               = "Identity pool for meshStack building blocks"
}

resource "google_iam_workload_identity_pool_provider" "meshstack" {
  lifecycle {
    enabled = local.original_runner_trust != null

    precondition {
      condition     = length(var.trusted_runner_identities) == 0 || var.workload_identity_federation.original_runner_uuid != null
      error_message = "A trusted runner needs meshstack.original_runner_ref. Set it to the runner that the definition ran on before it moved to another runner, and never remove it."
    }

    precondition {
      condition     = length(local.original_runner_trust.subjects) > 0
      error_message = "The building block runner ${local.original_runner_uuid} is a trusted runner, but no version of the definition runs on it, so there is nothing to trust. Remove it from meshstack.trusted_runner_refs."
    }
  }

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.meshstack.workload_identity_pool_id
  workload_identity_pool_provider_id = local.pool_identifier

  description = "OIDC identity provider for meshStack building blocks"

  oidc {
    issuer_uri        = local.original_runner_trust.issuer
    allowed_audiences = [local.original_runner_trust.audience]
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  attribute_condition = join(" || ", [
    for subject in local.original_runner_trust.subjects :
    "google.subject == '${subject}'"
  ])
}

resource "google_iam_workload_identity_pool_provider" "runner" {
  for_each = local.other_runner_trusts

  lifecycle {
    precondition {
      condition     = length(var.trusted_runner_identities) == 0 || var.workload_identity_federation.original_runner_uuid != null
      error_message = "A trusted runner needs meshstack.original_runner_ref. Set it to the runner that the definition ran on before it moved to another runner, and never remove it."
    }

    precondition {
      condition     = length(each.value.subjects) > 0
      error_message = "The building block runner ${each.key} is a trusted runner, but no version of the definition runs on it, so there is nothing to trust. Remove it from meshstack.trusted_runner_refs."
    }
  }

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.meshstack.workload_identity_pool_id
  workload_identity_pool_provider_id = "runner-${substr(each.key, 0, 8)}"

  description = "OIDC identity provider for meshStack building blocks on runner ${each.key}"

  oidc {
    issuer_uri        = each.value.issuer
    allowed_audiences = [each.value.audience]
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  attribute_condition = join(" || ", [
    for subject in each.value.subjects :
    "google.subject == '${subject}'"
  ])
}

resource "google_service_account" "buildingblock" {
  depends_on = [google_project_service.required]

  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "GKE Temporary Namespace Access Building Block"
  description  = "Grants developers time-limited access to GKE namespaces"
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
