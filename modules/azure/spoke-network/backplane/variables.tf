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
