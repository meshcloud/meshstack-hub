variable "name" {
  type        = string
  default     = "meshstack-network"
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
