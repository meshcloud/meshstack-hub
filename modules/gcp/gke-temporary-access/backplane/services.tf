# To avoid disrupting other workloads when the building block backplane is destroyed
# disable_on_destroy is disabled.
resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    # Federated token exchange and service account impersonation at building block run time.
    "sts.googleapis.com",
    "iamcredentials.googleapis.com",
    "container.googleapis.com",
  ])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
