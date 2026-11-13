variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the service account will be created."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID where the service account will be granted permissions to manage network areas."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL, audience and subject list for the meshStack building block identity provider. The audience defaults to the one meshStack runners use for Azure tokens."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-network-area"
  nullable    = false
  description = "Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
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
