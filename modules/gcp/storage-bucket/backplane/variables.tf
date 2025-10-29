variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_account_id" {
  description = "The ID of the service account to create"
  type        = string
  default     = "buildingblock-storage-sa"
}

variable "workload_identity_federation" {
  description = "Configuration for workload identity federation"
  type = object({
    workload_identity_pool_identifier = string // Identifier for the workload identity pool
    audience                          = string // Audience for the OIDC tokens
    issuer                            = string // OIDC issuer URL
    subject                           = string // Subject for workload identity federation (e.g., system:serviceaccount:namespace:service-account-name)
    subject_token_file_path           = string // Path to the file containing the OIDC token
  })
  default = null
}