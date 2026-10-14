variable "github_owner" {
  type        = string
  description = "GitHub organization or user that owns the repository."
}

variable "github_app_id" {
  type        = string
  description = "GitHub App ID used to authenticate the GitHub provider."
}

variable "github_app_installation_id" {
  type        = string
  description = "GitHub App installation ID for the owner. Found under GitHub App settings → Install App → your org."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "PEM-encoded private key of the GitHub App."
}

variable "github_repository_name" {
  type        = string
  description = "Repository (without owner) the workflow and the Ansible playbook are committed to."
}

variable "github_branch" {
  type        = string
  default     = "main"
  description = "Branch the files are committed to and the workflow is dispatched on."
}
