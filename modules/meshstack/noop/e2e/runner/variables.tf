variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string

    # Base URL of the meshStack API, written into the runner config for API polling.
    meshstack_endpoint = string

    # Project the runner's Cloud Run service and Secret Manager secrets live in.
    fixtures = object({
      gcp = object({
        project_id = string
      })
    })
  })
  nullable = false
}

variable "gcp_region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region for the Cloud Run service and Secret Manager replicas."
}
