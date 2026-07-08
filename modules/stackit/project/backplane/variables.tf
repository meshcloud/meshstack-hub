variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the service account will be created."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID where the service account will be granted permissions to create and manage projects."
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
  default     = "mesh-project"
  nullable    = false
  description = "Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}

variable "organization_onboarding_enabled" {
  type        = bool
  default     = true
  nullable    = false
  description = "Whether the service account is granted `iam.member-admin` so the building block pre-run script can add meshStack project users to the STACKIT organization."
}
