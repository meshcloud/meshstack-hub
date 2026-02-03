variable "name" {
  type        = string
  nullable    = false
  default     = "budget-alert"
  description = "name of the building block, used for naming resources"
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the building block should be deployable, typically the parent of all Landing Zones."
}

variable "existing_principal_ids" {
  type        = set(string)
  nullable    = false
  default     = []
  description = "set of existing principal ids that will be granted permissions to deploy the building block"
}

variable "create_service_principal_name" {
  type        = string
  nullable    = true
  default     = null
  description = "if set, creates a new service principal with the given name for deploying the building block"
}

variable "workload_identity_federation" {
  type = object({
    issuer  = string
    subject = string
  })
  nullable    = true
  default     = null
  description = "if set, configures workload identity federation for the created service principal"
}