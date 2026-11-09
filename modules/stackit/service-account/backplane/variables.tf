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

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL, audience and subject list for the meshStack building block identity provider. The audience defaults to the one meshStack runners use for Azure tokens."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-service-account"
  nullable    = false
  description = "Name of the backplane service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}
