variable "name" {
  type        = string
  default     = "meshstack-cce"
  nullable    = false
  description = "Name of the identity provider, the IAM group and the virtual user the building block signs in as. Unique across the domain."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subject  = string
    audience = string
  })
  nullable    = false
  description = "Identity the building block's runs present: the meshStack issuer, the definition's subject, and the audience of the token the pre-run script exchanges."
}

variable "create_cce_admin_trust" {
  type        = bool
  default     = true
  nullable    = false
  description = "Create the `cce_admin_trust` agency CCE needs in the region. It is one per domain, so only one backplane in a domain may create it; set false where it already exists."
}

variable "runner_uuid" {
  type        = string
  default     = null
  description = "The uuid of the runner that `workload_identity_federation` describes. It names the identity provider of that runner when the runner is not the original one."
}

variable "original_runner_uuid" {
  type        = string
  default     = null
  description = "The uuid of the runner whose identity provider has the name `name`, as given in `var.meshstack.original_runner_ref`. Null means the runner in `runner_uuid`."
}

variable "trusted_runner_identities" {
  type = list(object({
    runner_uuid = string
    issuer      = string
    audience    = string
    subject     = string
  }))
  default     = []
  nullable    = false
  description = "Identities of other runners to trust besides the one in `workload_identity_federation`, one identity provider each. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for an entry with a null subject."
}
