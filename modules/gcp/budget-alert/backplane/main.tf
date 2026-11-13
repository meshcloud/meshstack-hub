data "google_project" "backplane" {
  project_id = var.backplane_project_id
}

resource "google_service_account" "backplane" {
  depends_on = [google_project_service.required]

  project      = data.google_project.backplane.project_id
  account_id   = var.backplane_service_account_name
  display_name = var.backplane_service_account_name
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

  project                   = data.google_project.backplane.project_id
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

  project                            = data.google_project.backplane.project_id
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

  project                            = data.google_project.backplane.project_id
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

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.backplane.name
  role               = "roles/iam.workloadIdentityUser"
  members            = ["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack.name}/*"]
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
