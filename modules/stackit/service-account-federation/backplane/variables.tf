variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the backplane service account is created in."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = optional(string, "api://AzureADTokenExchange")
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL, audience and subjects of the meshStack building block runs. The audience defaults to the one meshStack runners use for Azure tokens."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the backplane service account. Unique within the project."
}
