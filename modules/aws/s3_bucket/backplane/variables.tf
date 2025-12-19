variable "workload_identity_federation" {
  type = object({
    issuer   = string,
    audience = string,
    subjects = list(string)
  })
  default     = null
  description = "Set these options to add a trusted identity provider from meshStack to allow workload identity federation for authentication which can be used instead of access keys. Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*')."
}
