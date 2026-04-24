variable "name" {
  type        = string
  nullable    = false
  default     = "service-principal"
  description = "Name of the building block, used for naming resources"

  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the building block should be deployable (management group or subscription), typically the parent of all Landing Zones."
}

variable "existing_principal_ids" {
  type        = set(string)
  default     = []
  description = "Set of existing principal IDs that will be granted permissions to deploy the building block"
}

variable "create_service_principal_name" {
  type        = string
  default     = null
  description = "Name of a service principal to create and grant permissions to deploy the building block"

  validation {
    condition     = var.create_service_principal_name == null ? true : can(regex("^[-a-zA-Z0-9_]+$", var.create_service_principal_name))
    error_message = "Service principal name can only contain alphanumeric characters, hyphens, and underscores"
  }
}

variable "workload_identity_federation" {
  type = object({
    issuer  = string
    subject = string
  })
  default     = null
  description = "Configuration for workload identity federation. If not provided, an application password will be created instead."
}
