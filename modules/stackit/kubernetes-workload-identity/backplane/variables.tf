variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project both backplane service accounts are created in. A project of the platform team, not a tenant project."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the workload service account. The building block runs get one named `<name>-bb`."
}

variable "organization_id" {
  type        = string
  default     = null
  description = "STACKIT organization `organization_roles` are assigned on."

  validation {
    condition     = length(var.organization_roles) == 0 || var.organization_id != null
    error_message = "organization_roles need organization_id."
  }
}

variable "organization_roles" {
  type        = list(string)
  nullable    = false
  description = "Roles of the workload service account on the organization, e.g. `cost-management.cost.reader`."
}

variable "project_roles" {
  type        = list(string)
  nullable    = false
  description = "Roles of the workload service account on `project_id`."
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

variable "trusted_runner_identities" {
  type = list(object({
    runner_uuid = string
    issuer      = string
    audience    = string
    subject     = string
  }))
  default     = []
  nullable    = false
  description = "One entry per trusted runner, with the issuer, audience and subject of its tokens. The backplane creates one federated identity provider for each on the building block service account. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for a runner that no version uses. If the same apply changes the runner, the apply fails instead."
}
