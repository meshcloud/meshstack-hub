variable "name" {
  type        = string
  nullable    = false
  default     = "service-principal"
  description = "Name of the building block, used for naming the resource group, the managed identity and the role definition."

  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the backplane resource group and managed identity."
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the building block should be deployable (management group or subscription), typically the parent of all Landing Zones."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication from the meshStack replicator."
}
