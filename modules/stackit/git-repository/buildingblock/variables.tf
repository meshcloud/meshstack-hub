# ── Backplane inputs (static, set once per building block definition) ──────────

variable "forgejo_organization" {
  type        = string
  description = "STACKIT Git organization where the repository will be created"
}

variable "action_variables" {
  type        = map(string)
  description = "Map of Forgejo Actions variables to create in the repository."
  default     = {}
}

variable "action_secrets" {
  type        = map(string)
  description = "Map of Forgejo Actions secrets to create in the repository."
  sensitive   = false # the whole map is not sensitive, but map values are!
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.action_secrets) : (length(key) <= 30)])
    error_message = "Forgejo Actions secret names must be 30 characters or less."
  }
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


variable "workspace_members" {
  description = "Workspace members used for collaborator and optional STACKIT project access reconciliation."
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  default = []
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID hosting the shared Forgejo instance. Optional."
  default     = ""
}

variable "stackit_git_access_role_name" {
  type        = string
  description = "Name of the custom STACKIT project role used for shared Forgejo access."
  default     = "meshstack.forgejo_access"
}

variable "stackit_git_access_role_permissions" {
  type        = list(string)
  description = "Permissions assigned to the custom STACKIT project role."
  default     = ["iam.subject.get"]
}
