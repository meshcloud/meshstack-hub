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
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer, audience and subjects for federated authentication. The audience defaults to the one meshStack runners use for Azure tokens."
}

variable "trusted_runner_identities" {
  type = list(object({
    runner_uuid = string
    issuer      = string
    audience    = string
    subject     = string
  }))
  default     = []
  nullable    = false
  description = "Identities of other runners to trust besides the one in `workload_identity_federation`, one federated credential each. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for an entry with a null subject."
}
