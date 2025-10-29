variable "name" {
  type        = string
  description = "The name of the building block"
}

variable "scope" {
  type        = string
  description = "The scope at which the role definition will be created (e.g., subscription ID or management group ID)"
}

variable "existing_principal_ids" {
  type        = map(string)
  description = "Map of existing principal IDs to assign the role to"
  default     = {}
}

variable "create_service_principal_name" {
  type        = string
  description = "Name of the service principal to create for this building block (optional)"
  default     = null
}

variable "workload_identity_federation" {
  type = object({
    issuer  = string
    subject = string
  })
  description = "Configuration for workload identity federation (optional)"
  default     = null
}
