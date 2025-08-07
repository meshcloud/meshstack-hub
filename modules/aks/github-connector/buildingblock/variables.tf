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
