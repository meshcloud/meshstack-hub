variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID where the service account will be granted permissions to manage service accounts and role assignments."
}

variable "workload_identity_federations" {
  type = list(object({
    issuer   = string
    audience = string
    subject  = string
  }))
  nullable    = false
  description = "meshStack identities the service account trusts, one per building block runner. For more subjects of one issuer, pass one entry per subject."

  validation {
    condition     = length(var.workload_identity_federations) > 0
    error_message = "The service account needs at least one identity to trust."
  }

  validation {
    condition     = alltrue([for identity in var.workload_identity_federations : identity.subject != null])
    error_message = "These identities need a subject: ${join(", ", [for identity in var.workload_identity_federations : identity.issuer if identity.subject == null])}."
  }
}

variable "service_account_name" {
  type        = string
  default     = "mesh-service-account"
  nullable    = false
  description = "Name of the backplane service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}
