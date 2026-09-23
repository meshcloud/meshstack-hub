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

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
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
