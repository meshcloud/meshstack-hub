variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity, resource group and role definition."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Connectivity scope where the hub network can be deployed (management group or subscription ID). The deploy role definition and assignment are applied here."
}

variable "subscription_id" {
  type        = string
  nullable    = false
  description = "Subscription (bare GUID) where the UAMI and its resource group are created. Typically the hub/connectivity subscription so the identity lives in a stable, platform-owned place."

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
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication of the automation identity."
}
