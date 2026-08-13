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
