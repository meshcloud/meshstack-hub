variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the registry is created in — the platform-native tenant id of the tenant this building block is added to."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the registry is placed in."
}

variable "registry_name" {
  type        = string
  nullable    = false
  description = "Name of the STACKIT container registry (artifactory) to create in the project."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.registry_name))
    error_message = "registry_name must be lowercase alphanumeric or dashes, not starting or ending with a dash, at most 63 characters."
  }
}
