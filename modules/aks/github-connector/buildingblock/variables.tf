variable "namespace" {
  description = "Associated namespace in AKS."
  type        = string
}

variable "github_repo" {
  type = string
}

variable "branch" {
  description = "Branch to use for deployments. If not provided, defaults to 'main'. If a custom branch is provided, it will be created if it doesn't exist."
  type        = string
  default     = "main"
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
