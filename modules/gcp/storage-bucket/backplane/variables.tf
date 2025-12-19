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
  description = "Configuration for workload identity federation. Supports multiple subjects with exact matching and partial matching using startsWith()."
  type = object({
    workload_identity_pool_identifier = string       // Identifier for the workload identity pool
    audience                          = string       // Audience for the OIDC tokens
    issuer                            = string       // OIDC issuer URL
    subjects                          = list(string) // Subjects for workload identity federation - can use exact matches or startsWith patterns
    subject_token_file_path           = string       // Path to the file containing the OIDC token
  })
  default = null
}
