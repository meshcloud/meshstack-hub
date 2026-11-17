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
