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

# ── Clone options ──────────────────────────────────────────────────────────────

variable "clone_addr" {
  type        = string
  description = "Optional URL to clone into this repository, e.g. 'https://github.com/owner/repo.git'. Leave empty or `null` to create an empty repository."
  default     = "null" # supporting the null string is a workaround for the Panel UI which does not support empty string as default for optional value
}
