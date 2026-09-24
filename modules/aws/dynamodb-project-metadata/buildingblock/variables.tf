variable "workspace_identifier" {
  type        = string
  description = "meshStack workspace identifier."
}

variable "project_identifier" {
  type        = string
  description = "meshStack project identifier."
}

variable "platform_identifier" {
  type        = string
  description = "meshStack platform identifier (typically the AWS account name for AWS accounts)."
}

variable "platform_tenant_id" {
  type        = string
  description = "meshStack platform tenant id (the AWS account ID). Used as mesh_accountId, the DynamoDB partition key."
}

variable "account_status" {
  type        = string
  default     = "active"
  description = "Tenant/account status written to mesh_accountStatus. Defaults to 'active'; the pre-run script sets it to 'retired' on the destroy run (tenant deletion) so the item is kept instead of deleted. Not a meshStack input — internal plumbing only."
}

variable "users" {
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  default     = []
  description = "Project team members with their roles, injected by meshStack."
}

variable "aws_region" {
  type        = string
  description = "AWS region where the DynamoDB table is located."
}

variable "aws_dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB table to write project metadata to."
}

variable "partition_key_name" {
  type        = string
  default     = "AWS_ACCOUNT_ID"
  description = "Name of the DynamoDB table's partition key attribute (the AWS account ID). Must match the target table's key name exactly; override if your table uses a different attribute name."
}
