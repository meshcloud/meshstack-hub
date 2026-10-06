variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the VM is created and where the service account is granted the editor role."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-server"
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
