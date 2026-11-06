variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID whose projects the building block may create Secrets Manager instances in."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-secrets-manager"
  nullable    = false
  description = "Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
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

variable "custom_role_name" {
  type        = string
  default     = "mesh-secrets-manager"
  nullable    = false
  description = "Name of the custom organization role granting Secrets Manager rights. Must be unique in the organization. Override when deploying multiple backplane instances."

  validation {
    condition     = can(regex("^[a-z]([-.]?[a-z]){1,63}$", var.custom_role_name))
    error_message = "STACKIT custom role names contain only lowercase letters, single hyphens and dots, and start with a letter."
  }
}
