variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the registry is created in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  description = "STACKIT region the registry is placed in."
}

variable "registry_name" {
  type        = string
  nullable    = false
  description = "Base name of the registry, to which a random suffix is appended."

  # The API takes 5 to 255 characters and also allows dots and underscores. Dashes only, and a
  # tighter cap, keep the name usable as a Harbor project name and in an image reference. The cap is
  # 58 rather than 63 to leave room for the disposability suffix this module appends.
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{3,56}[a-z0-9]$", var.registry_name))
    error_message = "registry_name must be 5 to 58 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "bootstrap_robot_username" {
  type        = string
  nullable    = false
  default     = ""
  description = "Harbor robot linked to this run's STACKIT service account. Empty mints no robots."
}

variable "users" {
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  nullable    = false
  description = "Project users from meshStack, onboarded into the registry through `role_mapping`."
}

variable "role_mapping" {
  type        = map(list(string))
  nullable    = false
  description = "Maps meshStack project roles to STACKIT container registry roles. Unknown roles are ignored."
}

variable "mirrored_base_images" {
  type        = list(string)
  nullable    = false
  description = "Fully qualified upstream images to mirror into the registry as `<registry>/<name>:<tag>`."
}
