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

variable "init_shared_files" {
  description = "Whether to initialize shared files (README.md and Dockerfile) in the repository"
  type        = bool
  default     = true
}
