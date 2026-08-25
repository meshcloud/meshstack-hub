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
    subject_token_file_path           = string
  })
  nullable    = false
  description = "Workload identity federation settings, sourced from data.meshstack_integrations. The accepted subjects are a separate variable — see workload_identity_subjects."
}

# Deliberately not a field of workload_identity_federation. Its value names the building block
# definition, which in turn carries the credentials_json output — and OpenTofu tracks module input
# dependencies per variable, not per attribute. Folding the subjects into that object would make
# every resource that reads any of its fields depend on the building block definition, and the
# credentials would depend on themselves.
variable "workload_identity_subjects" {
  type        = list(string)
  nullable    = false
  description = "Full `sub` claims of the OIDC tokens the pool provider accepts, matched exactly. Each must name the building block definition that authenticates with these credentials."
}

variable "iam_propagation_delay_seconds" {
  type        = number
  description = "Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and billing-account grants are among the slower ones. Set to 0 if the backplane is always provisioned well before any building block run."
  default     = 180
}
