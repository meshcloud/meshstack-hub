# ── Backplane inputs (static, set once per building block definition) ──────────

variable "forgejo_base_url" {
  type        = string
  description = "STACKIT Git base URL"
  default     = "https://git-service.git.onstackit.cloud"
}

variable "forgejo_token" {
  type        = string
  description = "STACKIT Git API token (from backplane)"
  sensitive   = true
}

variable "forgejo_organization" {
  type        = string
  description = "STACKIT Git organization where the repository will be created"
}

# ── User inputs (set per building block instance) ─────────────────────────────

variable "name" {
  type        = string
  description = "Name of the Git repository to create"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.name))
    error_message = "Repository name must only contain alphanumeric characters, dots, dashes, or underscores."
  }
}

variable "description" {
  type        = string
  description = "Short description of the repository"
  default     = ""
}

variable "private" {
  type        = bool
  description = "Whether the repository should be private"
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
  description = "Create repository from a template repository given by template_repo_path instead of creating an empty one."
  default     = false
}

variable "template_repo_path" {
  type        = string
  description = "Path (owner/name) to the template repository."
  default     = ""

  validation {
    condition     = var.template_repo_path == "" || can(regex("^[^/]+/[^/]+$", var.template_repo_path))
    error_message = "template_repo_path must be in format owner/name."
  }
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
  description = "List of Forgejo events that trigger the webhook"
  default     = ["push", "create"]
}
