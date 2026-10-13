variable "name" {
  type        = string
  nullable    = false
  default     = "key-vault"
  description = "Name for the building block identity, its resource group and the role definitions."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the building block can be deployed (management group or subscription ID), typically the parent of all landing zones."
}

variable "hub_scope" {
  type        = string
  default     = null
  description = "Scope holding the hub vnet that private Key Vaults peer into (management group or subscription ID). Null grants no hub permissions, so the building block cannot peer."
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
