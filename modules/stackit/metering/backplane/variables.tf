variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project both backplane service accounts are created in. A project of the platform team, not a tenant project."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization whose costs the metering reads. The Cost API takes it as customer account."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  default     = "mesh-metering"
  description = "Name of the metering service account. The building block runs get one named `<name>-bb`."
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
