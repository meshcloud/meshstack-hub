provider "google" {
  project = var.test_context.fixtures.gcp.project_id
  region  = var.gcp_region
}
