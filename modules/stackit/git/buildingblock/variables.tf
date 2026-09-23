variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the Git instance is created in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  description = "STACKIT region the Git instance is placed in."
}

variable "instance_name" {
  type        = string
  nullable    = false
  description = "First label of the instance hostname `<name>.git.onstackit.cloud`, globally unique across all of STACKIT."

  validation {
    # A hostname label: STACKIT publishes the instance as `<name>.git.onstackit.cloud`, so whatever
    # else the API accepts, a name that is not a valid DNS label cannot be reached.
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.instance_name))
    error_message = "instance_name must be a DNS label: lowercase alphanumeric or dashes, not starting or ending with a dash, at most 63 characters."
  }
}

variable "forgejo_organization" {
  type        = string
  nullable    = true
  description = "Forgejo organization to create inside the instance. Empty provisions the bare instance."
}

variable "local_user_username" {
  type        = string
  nullable    = false
  description = "Username of the technical user the module mints its token on."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,31}$", var.local_user_username))
    error_message = "local_user_username must be at most 32 characters of alphanumerics, dots, dashes or underscores, starting with an alphanumeric."
  }
}

variable "local_user_email" {
  type        = string
  nullable    = false
  description = "Email of the technical user. Leave empty to derive one from the instance hostname."
}

variable "local_user_token_name" {
  type        = string
  nullable    = false
  description = "Name of the Personal Access Token the module mints."
}

variable "local_user_token_scopes" {
  type        = list(string)
  nullable    = false
  description = "Forgejo scopes of the minted token."
}

variable "shared_runner_labels" {
  type        = list(string)
  nullable    = false
  description = "Labels of the STACKIT-hosted shared runner to order. Leave empty to order none."
}
