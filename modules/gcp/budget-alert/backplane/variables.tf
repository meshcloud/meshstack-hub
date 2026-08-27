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
    audience                          = string
    issuer                            = string
    subjects                          = list(string)
    subject_token_file_path           = string
  })
  nullable    = false
  description = "Workload identity federation settings, sourced from data.meshstack_integrations."
}

variable "iam_propagation_delay_seconds" {
  type        = number
  description = "Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and billing-account grants are among the slower ones. Set to 0 if the backplane is always provisioned well before any building block run."
  default     = 180
}
