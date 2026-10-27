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
