variable "enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "When false, create no service account, federated identity or role grant."

  validation {
    condition     = !var.enabled || (var.project_id != null && var.folder_id != null)
    error_message = "project_id and folder_id are required when enabled is true."
  }
}

variable "project_id" {
  type        = string
  nullable    = true
  default     = null
  description = "Existing STACKIT project the automation service account is created in, not the project the registry ends up in. Null when enabled is false."
}

variable "folder_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT resource-manager folder (`folder_id`, not container_id) the service account is granted roles on, inherited by every project inside it. Null when enabled is false."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  default     = ["editor", "container-registry.admin"]
  description = <<-EOT
  Roles granted to the service account on the folder.

  `editor` is the narrowest folder role carrying `service-enablement.service-state.edit`.
  `cloud.stackit.container-registry` is DISABLED by default on every project measured, so the
  service has to be switched on before an artifactory can be created in it.

  `container-registry.admin` carries `container-registry.project.create`.

  Neither role opens the Harbor API itself — no STACKIT IAM role does. Harbor access comes from
  linking a robot to a service account in the portal; see the building block README.
  EOT
}

variable "service_account_name" {
  type        = string
  nullable    = false
  default     = "mesh-stackit-cr"
  description = "Name of the STACKIT automation service account. STACKIT caps this at 20 characters."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
}
