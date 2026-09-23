variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where Secrets Manager instances will be created."
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
