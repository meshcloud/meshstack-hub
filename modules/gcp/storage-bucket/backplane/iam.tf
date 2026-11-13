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
  # Nothing below references the APIs, so Terraform cannot infer this ordering on its own.
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

  # Map the OIDC token's `sub` claim to google.subject
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  # Restrict token acceptance to configured subjects
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
