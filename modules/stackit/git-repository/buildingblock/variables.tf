# ── Backplane inputs (static, set once per building block definition) ──────────

variable "gitea_base_url" {
  type        = string
  description = "STACKIT Git base URL"
  default     = "https://git-service.git.onstackit.cloud"
}

variable "gitea_token" {
  type        = string
  description = "STACKIT Git API token (from backplane)"
  sensitive   = true
}

variable "gitea_organization" {
  type        = string
  description = "STACKIT Git organization where the repository will be created"
}

# ── User inputs (set per building block instance) ─────────────────────────────

variable "repository_name" {
  type        = string
  description = "Name of the Git repository to create"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.repository_name))
    error_message = "Repository name must only contain alphanumeric characters, dots, dashes, or underscores."
  }
}

variable "repository_description" {
  type        = string
  description = "Short description of the repository"
  default     = ""
}

variable "repository_private" {
  type        = bool
  description = "Whether the repository should be private"
  default     = true
}

variable "repository_auto_init" {
  type        = bool
  description = "Auto-initialize the repository with a README"
  default     = true
}

variable "default_branch" {
  type        = string
  description = "Default branch name"
  default     = "main"
}

# ── Template options ───────────────────────────────────────────────────────────

variable "use_template" {
  type        = bool
  description = "Create repository from a template repository instead of creating an empty one"
  default     = false
}

variable "template_owner" {
  type        = string
  description = "Owner/organization of the template repository"
  default     = "stackit"
}

variable "template_name" {
  type        = string
  description = "Name of the template repository"
  default     = "app-template-python"
}

variable "template_repo_name" {
  type        = string
  description = "Value for the REPO_NAME variable used during template substitution"
  default     = ""
}

variable "template_namespace" {
  type        = string
  description = "Value for the NAMESPACE variable used during template substitution"
  default     = ""
}

# ── Webhook options ────────────────────────────────────────────────────────────

variable "webhook_url" {
  type        = string
  description = "Webhook URL to configure (e.g., Argo Workflows EventSource URL). Leave empty to skip."
  default     = ""
}

variable "webhook_secret" {
  type        = string
  description = "Secret for webhook authentication"
  sensitive   = true
  default     = ""
}

variable "webhook_events" {
  type        = list(string)
  description = "List of Gitea events that trigger the webhook"
  default     = ["push", "create"]
}
