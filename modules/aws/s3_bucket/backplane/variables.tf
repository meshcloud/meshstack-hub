variable "workload_identity_federations" {
  type = list(object({
    issuer   = string
    audience = string
    subject  = string
  }))
  nullable    = false
  description = <<-EOT
  meshStack identities the role trusts, one per building block runner. For more subjects of one
  issuer, pass one entry per subject. The backplane looks up this account's OIDC provider for each issuer.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT

  validation {
    condition     = length(var.workload_identity_federations) > 0
    error_message = "The role needs at least one identity to trust."
  }

  validation {
    condition     = alltrue([for identity in var.workload_identity_federations : identity.subject != null])
    error_message = "These identities need a subject: ${join(", ", [for identity in var.workload_identity_federations : identity.issuer if identity.subject == null])}."
  }
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name for the backplane IAM role and policy (suffixed -role and -policy)."
}
