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
  description = "Existing STACKIT project the automation service account is created in, not the project the Git instance ends up in. Null when enabled is false."
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
  default     = ["git.admin"]
  description = <<-EOT
  Roles granted to the service account on the folder so it can create Git instances in the projects
  inside it. `git.admin` is the narrow role and is assignable at folder scope — both verified
  against the live authorization API (`GET https://authorization.api.stackit.cloud/v2/folder/<folder_id>/roles`).
  It carries instance create/get/list/update/delete, the instance users and authentication-source
  calls, the runners and the flavor list, and nothing outside STACKIT Git. `git.reader` exists for a
  read-only variant.

  No service-enablement permission is needed on top: `cloud.stackit.git` is among the services
  STACKIT enables by default on a new project, measured across four projects including three
  landing-zone-created foundations (`GET https://service-enablement.api.stackit.cloud/v2/projects/<project_id>/regions/<region>/services`).
  Creating the first instance therefore never has to enable the service, which is why this module
  needs nothing beyond `git.admin` while the SKE cluster backplane needs `editor` — SKE is disabled
  by default, STACKIT Git is not.
  EOT
}

variable "service_account_name" {
  type        = string
  nullable    = false
  default     = "mesh-stackit-git"
  description = "Name of the STACKIT automation service account. STACKIT caps this at 20 characters."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
}
