variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the backplane service account is created in."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL, audience and subjects of the meshStack building block runs. The audience defaults to the one meshStack runners use for Azure tokens."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the backplane service account. Unique within the project."
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
  description = "One entry per trusted runner, with the issuer, audience and subject of its tokens. The backplane creates one federated identity provider for each. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for a runner that no version uses. If the same apply changes the runner, the apply fails instead."
}
