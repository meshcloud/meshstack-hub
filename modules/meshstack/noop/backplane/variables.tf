variable "meshstack_workspace_identifier" {
  type        = string
  description = "Identifier of the meshStack workspace that will own the runner and API key."
}

variable "meshstack_endpoint" {
  type        = string
  description = "Base URL of the meshStack API (e.g. https://federation.example.meshcloud.io). Used by both the Terraform provider and the runner config."
}

variable "runner_display_name" {
  type        = string
  default     = "meshstack-noop-tf-runner"
  description = "Display name for the meshStack building block runner and API key."
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where Cloud Run and Secret Manager resources are deployed."
}

variable "gcp_region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region for the Cloud Run service."
}

variable "gcp_runner_image" {
  type        = string
  description = "Container image URI for the meshStack runner (e.g. ghcr.io/meshcloud/tf-block-runner:latest)."
  default     = "ghcr.io/meshcloud/tf-block-runner:latest"
}

variable "gcp_resource_name_prefix" {
  type        = string
  default     = "meshstack-runner"
  description = "Prefix for GCP resource names (Cloud Run service, Secret Manager secrets). Must be lowercase letters, numbers, and hyphens only."
}
