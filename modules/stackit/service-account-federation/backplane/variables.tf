variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the backplane service account is created in."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization the backplane service account gets `iam.member-admin` in."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subjects of the meshStack building block runs."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the backplane service account. Unique within the project."
}
