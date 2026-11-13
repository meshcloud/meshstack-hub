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
  description = "Identities of other runners to trust besides the one in `workload_identity_federation`, one federated identity provider each. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for an entry with a null subject."
}
