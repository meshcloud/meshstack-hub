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
  description = "Workload identity federation settings describing the building block runner."
  type = object({
    workload_identity_pool_identifier = string // Identifier for the workload identity pool
    subject_token_file_path           = string // Path to the file containing the OIDC token
  })
  nullable = false
}

# Apart, because Terraform depends on a whole variable rather than the attribute read: these come
# from the building block definition's `version_latest`, and reading them next to the pool identifier would
# put `credentials_json` behind the definition that consumes it.
variable "workload_identity_federation_trust" {
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  nullable    = false
  description = "What the pool provider trusts: the runner's OIDC issuer and audience, and the subject claims it accepts, each matched exactly. Take them from `version_latest.workload_identity_federation` of the building block definitions that run here."
}

