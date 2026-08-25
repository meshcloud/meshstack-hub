variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_account_id" {
  description = "The ID of the service account to create"
  type        = string
  default     = "buildingblock-storage-sa"
}

variable "iam_propagation_delay_seconds" {
  description = "Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and Google's guidance is to allow two to seven minutes before retrying a denied impersonation. Set to 0 if the backplane is always provisioned well before any building block run."
  type        = number
  default     = 180
}

variable "workload_identity_federation" {
  description = "Workload identity federation settings, sourced from data.meshstack_integrations. The accepted subjects are a separate variable — see workload_identity_subjects."
  type = object({
    workload_identity_pool_identifier = string // Identifier for the workload identity pool
    audience                          = string // Audience for the OIDC tokens
    issuer                            = string // OIDC issuer URL
    subject_token_file_path           = string // Path to the file containing the OIDC token
  })
  nullable = false
}

# Deliberately not a field of workload_identity_federation. Its value names the building block
# definition, which in turn carries the credentials_json output — and OpenTofu tracks module input
# dependencies per variable, not per attribute. Folding the subjects into that object would make
# every resource that reads any of its fields depend on the building block definition, and the
# credentials would depend on themselves.
variable "workload_identity_subjects" {
  description = "Full `sub` claims of the OIDC tokens the pool provider accepts, matched exactly. Each must name the building block definition that authenticates with these credentials."
  type        = list(string)
  nullable    = false
}
