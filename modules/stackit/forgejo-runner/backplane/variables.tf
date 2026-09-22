variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the backplane service account is created and the runner VM will be provisioned."
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
  default     = "mesh-forgejo-runner"
  nullable    = false
  description = "Name of the backplane service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}
