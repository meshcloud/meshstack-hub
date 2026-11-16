variable "runner_identities" {
  type = list(object({
    issuer   = string
    audience = string
    subject  = string
  }))
  default     = []
  nullable    = false
  description = <<-EOT
  AWS lets a run assume the role when its token matches one of these entries.
  Pass the output `identities` of modules/meshstack/runner-identity.
  The backplane skips an entry with a null subject, but still looks up the provider of its issuer.
  Create the IAM OIDC provider of each issuer in this AWS account first.
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
  One more entry like those in `runner_identities`, for a caller without modules/meshstack/runner-identity. Set `oidc_provider_arn` with it.
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
