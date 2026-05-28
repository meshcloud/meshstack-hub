variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity and role definitions."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed."
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope for role assignment on landing zone (management group or subscription ID)."
}

variable "hub_scope" {
  type        = string
  nullable    = false
  description = "Scope for hub VNet peering role assignment."
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the UAMI resource."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication."
}
