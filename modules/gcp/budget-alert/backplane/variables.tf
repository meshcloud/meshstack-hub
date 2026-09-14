variable "backplane_project_id" {
  type        = string
  description = "The project hosting the building block backplane resources"
}

variable "billing_account_id" {
  type        = string
  description = "The billing account ID where budget permissions will be granted"
}

variable "backplane_service_account_name" {
  type        = string
  description = "The name of the service account to be created for the backplane"
  default     = "building-block-budget-alert"
}

variable "workload_identity_federation" {
  type = object({
    workload_identity_pool_identifier = string
    subject_token_file_path           = string
  })
  nullable    = false
  description = "Workload identity federation settings describing the building block runner."
}

# Apart, because Terraform depends on a whole variable rather than the attribute read: these come
# from the building block definition's status, and reading them next to the pool identifier would
# put `credentials_json` behind the definition that consumes it.
variable "workload_identity_federation_trust" {
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  nullable    = false
  description = "What the pool provider trusts: the runner's OIDC issuer and audience, and the subject claims it accepts, each matched exactly. Take them from the resolved status of the building block definitions that run here."
}

variable "iam_propagation_delay_seconds" {
  type        = number
  description = "Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and billing-account grants are among the slower ones. Set to 0 if the backplane is always provisioned well before any building block run."
  default     = 180
}
