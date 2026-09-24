variable "workspace_identifier" {
  type = string
}

variable "workspace_members" {
  description = "Workspace members used for team-based access management."
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  nullable = false
}

variable "forgejo_organization" {
  type        = string
  description = "STACKIT Git organization where the repository will be created"
}

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
  nullable    = false
  description = "Short description of the repository."
}

variable "private" {
  type        = bool
  nullable    = false
  description = "Whether the repository should be private."
}

variable "default_branch" {
  type        = string
  nullable    = false
  description = "Default branch of an empty repository; a clone keeps the source's."
}

variable "clone_addr" {
  type        = string
  nullable    = false
  description = "Public Git URL cloned once into the repository. Empty or `null` creates an empty repository."
}

variable "action_variables" {
  type        = map(string)
  nullable    = false
  description = "Map of Forgejo Actions variables to create in the repository."
}

variable "extra_action_variables" {
  type        = map(string)
  nullable    = false
  description = "Forgejo Actions variables for this repository only, merged over `action_variables`."
}

variable "action_secrets" {
  type        = map(string)
  description = "Map of Forgejo Actions secrets to create in the repository."
  nullable    = false
  sensitive   = false # the whole map is not sensitive, but map values are!

  validation {
    condition     = alltrue([for key in keys(var.action_secrets) : (length(key) <= 30)])
    error_message = "Forgejo Actions secret names must be 30 characters or less."
  }
}

variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project of the Git instance."
}

variable "stackit_git_instance_id" {
  type        = string
  nullable    = false
  description = "STACKIT Git instance whose users are matched to workspace members by email."
}

variable "hub_git_ref" {
  type        = string
  description = "Hub git ref this building block runs from. Pins the shared modules it sources so they stay in lockstep with this module's own checkout."
  const       = true
  default     = "main"
}
