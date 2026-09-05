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
  description = "meshStack platform identifier (typically the AWS account ID for AWS tenants)."
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
