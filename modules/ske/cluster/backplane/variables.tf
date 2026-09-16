variable "enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "When false, the backplane creates no service account, federated identity or role grant. Used by a composing setup that provides the automation identity externally. Kept as an in-module toggle (not a module-level count) so the identity module stays in the graph and no reference cycle is introduced."

  validation {
    condition     = !var.enabled || (var.project_id != null && var.organization_id != null)
    error_message = "project_id and organization_id are required when enabled is true."
  }
}

variable "project_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT project the automation service account is created in. This is an existing project (e.g. a foundation project) — NOT the cluster's project, which may not exist yet when the backplane is applied. Unused (leave null) when enabled is false."
}

variable "organization_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT organization the service account is granted roles on. Roles are assigned at the organization so they are inherited by projects created later (the SKE cluster's project is provisioned at order time). Unused (leave null) when enabled is false."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  default     = ["ske.admin"]
  description = "Organization-level roles granted to the service account so it can manage SKE in the (later-created) cluster project. Adjust to the exact STACKIT role names your organization uses."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  default     = "mesh-ske-cluster"
  description = "Name of the STACKIT automation service account."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
}
