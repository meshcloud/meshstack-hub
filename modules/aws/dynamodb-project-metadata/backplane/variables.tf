variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  description = <<-EOT
  Workload identity federation configuration. Allows the meshStack building block runtime to assume
  an IAM role via OIDC without long-lived credentials.
  EOT
}

variable "table_name" {
  type        = string
  default     = "meshstack-project-metadata"
  description = "Name of the DynamoDB table to create for storing meshStack project metadata."
}
