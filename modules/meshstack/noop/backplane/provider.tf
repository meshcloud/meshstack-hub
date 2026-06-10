provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "meshstack" {
  endpoint = var.meshstack_endpoint
}
