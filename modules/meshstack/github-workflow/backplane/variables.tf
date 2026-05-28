variable "github_owner" {
  type        = string
  description = "GitHub organization or user that owns the repository."
}

variable "github_base_url" {
  type        = string
  default     = "https://github.com"
  description = "Base URL of the GitHub instance. Override for GitHub Enterprise Server."
}

variable "github_app_id" {
  type        = string
  description = "GitHub App ID used to authenticate the GitHub provider."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "PEM-encoded private key for the GitHub App used to authenticate the GitHub provider."
}

variable "github_app_installation_id" {
  type        = string
  description = "GitHub App installation ID for the owner (organization or user). Found under GitHub App settings → Install App → your org."
}

variable "github_repository_name" {
  type        = string
  description = "GitHub repository name (without owner), for example: meshstack-noop-github-workflow."
}

variable "github_branch" {
  type        = string
  default     = "main"
  description = "Branch where workflow files should be committed."
}

variable "github_apply_workflow" {
  type        = string
  default     = "apply.yml"
  description = "Workflow filename to trigger on apply."
}

variable "github_apply_workflow_async" {
  type        = string
  default     = "apply-async.yml"
  description = "Workflow filename to trigger on apply in async mode."
}

variable "github_destroy_workflow" {
  type        = string
  default     = "destroy.yml"
  description = "Workflow filename to trigger on destroy."
}

variable "github_destroy_workflow_async" {
  type        = string
  default     = "destroy-async.yml"
  description = "Workflow filename to trigger on destroy in async mode."
}

variable "workflow_name_prefix" {
  type        = string
  default     = "meshstack"
  description = "Prefix for generated workflow display names."
}

