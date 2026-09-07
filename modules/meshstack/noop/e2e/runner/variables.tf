variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string

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

# Not secret, so this belongs in test_context (see the e2e-test skill) — but the harness does not
# publish it there yet; it reaches CI through the secret pipe. Move it over once it does.
variable "meshstack_endpoint" {
  type        = string
  description = "Base URL of the meshStack API. Written into the runner config for API polling."
}
