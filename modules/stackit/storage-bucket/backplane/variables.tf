variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where Object Storage buckets will be created."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-storage-bucket"
  nullable    = false
  description = "Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL, audience and subject list for the meshStack building block identity provider. The audience defaults to the one meshStack runners use for Azure tokens."
}
