variable "region" {
  type        = string
  default     = "eu-de"
  nullable    = false
  description = "T Cloud Public region the project is created in. The project name is prefixed with it, as T Cloud Public requires."
}

variable "project_name" {
  type        = string
  nullable    = false
  description = "Name of the project without the region prefix. The project is created as `<region>_<project_name>`."

  validation {
    # T Cloud Public allows letters, digits, `-` and `_`. Group names are `<region>_<project_name>_<role>`
    # and capped at 64 characters, so the project name gets what is left after the longest role suffix.
    condition     = can(regex("^[a-zA-Z0-9_-]{1,48}$", var.project_name))
    error_message = "project_name must be 1-48 letters, digits, dashes or underscores."
  }
}

variable "users" {
  description = "List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to T Cloud Public roles via `role_mapping`."
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

variable "role_mapping" {
  type        = map(list(string))
  nullable    = false
  description = "Maps each meshStack role to the T Cloud Public system roles (by role `name`, e.g. `te_admin`, `readonly`) its project group gets. Unknown meshStack roles in `users` are ignored."
}

variable "mapping_bucket" {
  type        = string
  default     = null
  description = "OBS bucket the federation mapping building block rebuilds the identity provider's mapping from. Null means no federation: members are then put into the groups as existing local IAM users instead, named like the part of their email before the `@`."
}

variable "console_login_url" {
  type        = string
  default     = "https://console.otc.t-systems.com"
  nullable    = false
  description = "Where project users sign in — the identity provider's login link when federation is set up."
}
