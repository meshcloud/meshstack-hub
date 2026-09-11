# The backplane only exists in hub mode, so its provider is configured here rather than in the root.
# Foundation mode then never installs the google provider at all, and needs no GCP credential.
#
# A module holding a provider block may not take `count`, `for_each` or `depends_on` — so keep those
# off the `module "definition"` block in the root.
provider "google" {
  # Credentials come from the environment: Application Default Credentials locally, WIF in CI.
  project = var.test_context.fixtures.gcp.project_id
}
