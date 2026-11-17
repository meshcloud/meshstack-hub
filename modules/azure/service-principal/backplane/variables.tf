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
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer, audience and subjects for federated authentication from the meshStack replicator. The audience defaults to the one meshStack runners use for Azure tokens."
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
  description = "One entry per trusted runner, with the issuer, audience and subject of its tokens. The backplane creates one federated credential for each. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for a runner that no version uses. If the same apply changes the runner, the apply fails instead."
}
