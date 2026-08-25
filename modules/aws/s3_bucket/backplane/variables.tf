variable "workload_identity_federation" {
  type = object({
    issuer   = string,
    audience = string,
    subjects = list(string)
  })
  nullable    = false
  description = <<-EOT
  Trusted identity provider from meshStack that the building block runner federates into.
  Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*').
  EOT
}

variable "oidc_provider_arn" {
  type        = string
  nullable    = false
  description = <<-EOT
  ARN of the IAM OIDC provider for the meshStack runner WIF token issuer in this AWS account.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT
}
