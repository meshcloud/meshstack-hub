variable "namespace" {
  description = "Associated namespace in AKS."
  type        = string
}

variable "github_repo" {
  type = string
}

variable "github_environment_name" {
  description = "Name of the GitHub environment to use for deployments."
  type        = string
  default     = "production"
}

variable "additional_environment_variables" {
  type        = map(string)
  description = "Map of additional environment variable key/value pairs to set as GitHub Actions environment variables."
  default     = {}
}

variable "workflow_filename" {
  type        = string
  description = "Filename of the GitHub Actions workflow to dispatch after connector setup (e.g. 'k8s-deploy.yml'). The workflow must have 'on: workflow_dispatch'. Set to empty string to skip."
  default     = "k8s-deploy.yml"
}
