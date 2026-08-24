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

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set to false if the OIDC provider for the meshStack issuer already exists in this AWS account (e.g., created by another backplane). The existing provider will be looked up by URL instead of created."
}
