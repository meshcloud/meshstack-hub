variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string
  })
  nullable = false
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID for the runner Cloud Run service and Secret Manager secrets."
}

variable "gcp_region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region for the Cloud Run service and Secret Manager replicas."
}

variable "meshstack_endpoint" {
  type        = string
  description = "Base URL of the meshStack API. Written into the runner config for API polling."
}
