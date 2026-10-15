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
  description = "Name of the DynamoDB table to create for storing meshStack account metadata."
}

variable "partition_key_name" {
  type        = string
  description = "Name of the table's partition key attribute (the AWS account ID). Must match the building block's partition_key_name and the target table's key name exactly."
}
