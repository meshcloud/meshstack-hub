variable "runner_identities" {
  type = list(object({
    issuer   = string
    audience = string
    subject  = string
  }))
  default     = []
  nullable    = false
  description = <<-EOT
  The meshStack identities the role trusts, one per building block runner: the output `identities` of
  modules/meshstack/runner-identity. An entry with a null subject is skipped.
  The backplane looks up the IAM OIDC provider of each issuer in this AWS account.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string,
    audience = string,
    subjects = list(string)
  })
  default     = null
  description = <<-EOT
  One more identity the role trusts, for a caller that does not use `runner_identities`. It needs `oidc_provider_arn`.
  Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*').
  EOT
}

variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = <<-EOT
  ARN of the IAM OIDC provider for the issuer of `workload_identity_federation` in this AWS account.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name for the backplane IAM role and policy (suffixed -role and -policy)."
}
