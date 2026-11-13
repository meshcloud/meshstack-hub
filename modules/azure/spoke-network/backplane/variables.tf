variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity, resource group and role definitions."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the spoke network can be deployed (management group or subscription ID), typically the parent of all landing zones."
}

variable "hub_scope" {
  type        = string
  nullable    = false
  description = "Scope where the hub vnet lives (management group or subscription ID). The identity is granted vnet peering permissions here so it can peer the spoke into the hub."
}

variable "subscription_id" {
  type        = string
  nullable    = false
  description = "Subscription (bare GUID) where the UAMI and its resource group are created. Typically the hub subscription so the identity lives in a stable, platform-owned place. Deploy the backplane once per hub environment (e.g. hub-dev, hub-prod) with the respective subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Must be a bare subscription GUID, not a '/subscriptions/<guid>' path."
  }
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the UAMI resource group."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer, audience and subjects for federated authentication of the automation identity. The audience defaults to the one meshStack runners use for Azure tokens."
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
