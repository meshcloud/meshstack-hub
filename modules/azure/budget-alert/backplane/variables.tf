variable "name" {
  type        = string
  nullable    = false
  default     = "budget-alert"
  description = "Name for the building block identity and role definition."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope for role assignment (management group or subscription ID)."
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the UAMI resource."
}

variable "resource_group_name" {
  type        = string
  nullable    = false
  description = "Resource group where the UAMI will be created."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication."
}