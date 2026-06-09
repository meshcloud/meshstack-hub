variable "name" {
  type        = string
  nullable    = false
  description = "Name for the UAMI and related backplane resources. Must match pattern ^[-a-z0-9]+$."

  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only lowercase alphanumeric characters and dashes are allowed."
  }
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the backplane resource group and UAMI."
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope for role assignment (management group or subscription ID)."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication from the meshStack replicator."
}
