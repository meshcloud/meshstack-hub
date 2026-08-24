provider "google" {
  # Billing budget calls are billed to a quota project; the backplane project is where the API is
  # enabled and where the service account this runs as lives.
  project = var.backplane_project_id
}
