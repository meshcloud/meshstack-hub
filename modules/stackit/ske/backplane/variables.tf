variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the service account will be created."
}

variable "folder_id" {
  type        = string
  nullable    = false
  description = "STACKIT folder ID under which the tenant projects live. The service account is granted 'ske.admin' on this folder, which covers every project below it."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-ske"
  nullable    = false
  description = "Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}

variable "additional_roles_project_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT project the roles in `additional_project_roles` are granted on. Name the project a composition needs the identity to reach beyond the tenant folder — for example the project that owns a shared DNS zone."
}

variable "additional_project_roles" {
  type     = set(string)
  nullable = false
  default  = []

  description = <<-EOT
  Extra STACKIT roles granted to the service account at **project** scope, on
  `additional_roles_project_id`.

  A composition that runs more than the SKE module with this one identity needs the roles those
  other modules require. The `stackit-kubernetes` reference architecture writes each cluster's
  wildcard record into a DNS zone the platform team owns, so it passes `["dns.admin"]` with the
  zone's project. Project scope is right for that grant because the zone's project is a static
  input the platform team fills in when it registers the building block — unlike `ske.admin`, whose
  target project is whichever tenant orders a cluster and is therefore unknowable here.
  EOT

  validation {
    condition     = length(var.additional_project_roles) == 0 || try(length(var.additional_roles_project_id) > 0, false)
    error_message = "additional_project_roles names roles to grant on a project, so additional_roles_project_id has to name that project."
  }
}
