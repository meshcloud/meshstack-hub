variable "enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "When false, the backplane creates no service account, federated identity or role grant. Used by a composing setup that provides the automation identity externally. Kept as an in-module toggle (not a module-level count) so the identity module stays in the graph and no reference cycle is introduced."

  validation {
    condition     = !var.enabled || (var.project_id != null && var.folder_id != null)
    error_message = "project_id and folder_id are required when enabled is true."
  }
}

variable "project_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT project the automation service account is created in. This is an existing project (e.g. a foundation project) — NOT the cluster's project, which may not exist yet when the backplane is applied. Unused (leave null) when enabled is false."
}

variable "folder_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT resource-manager folder the service account is granted roles on. Roles are assigned on the folder so they are inherited by every project inside it (the SKE cluster's project is provisioned at order time inside this folder). This is the folder's `folder_id`, not its container_id. Unused (leave null) when enabled is false."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  default     = ["ske.admin"]
  description = "Roles granted to the service account on the folder so it can manage SKE in the projects created inside it. Assigned at folder scope, where STACKIT service roles like `ske.admin` are valid (they are rejected at organization scope). Query available roles with `stackit curl https://authorization.api.stackit.cloud/v2/folder/<folder_id>/roles`."
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
