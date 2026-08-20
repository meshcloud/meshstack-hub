# Project APIs this building block depends on. Enabling them is part of preparing the cloud side,
# which is what a backplane is for — a project that has never used IAM answers every call below
# with `SERVICE_DISABLED` until these are on.
#
# `disable_on_destroy = false` is deliberate and load-bearing: destroying this backplane must not
# switch project-wide APIs off. A backplane can be short-lived (an e2e test provisions and tears one
# down per run) and it never owns the project exclusively, so disabling `storage.googleapis.com` on
# teardown would break every other tenant of the same project.
resource "google_project_service" "required" {
  for_each = toset([
    # Backplane resources below: service accounts, workload identity pools and providers.
    "iam.googleapis.com",
    # Project-level IAM bindings (google_project_iam_member).
    "cloudresourcemanager.googleapis.com",
    # Building block run time, workload identity path: the runner exchanges its meshStack OIDC
    # token via STS and then impersonates the service account via iamcredentials. Enabled
    # unconditionally to keep the set static — they are inert on the service account key path.
    "sts.googleapis.com",
    "iamcredentials.googleapis.com",
    # Building block run time: the buckets the building block creates.
    "storage.googleapis.com",
  ])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
