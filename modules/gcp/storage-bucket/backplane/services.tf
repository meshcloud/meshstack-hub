# A backplane never owns its project exclusively and can be short-lived, so `disable_on_destroy`
# stays false: switching these APIs off on teardown would break every other tenant of the project.
resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    # Used by the workload identity path only. Enabled anyway, so the set does not depend on which
    # credential path the backplane was configured for.
    "sts.googleapis.com",
    "iamcredentials.googleapis.com",
    "storage.googleapis.com",
  ])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
