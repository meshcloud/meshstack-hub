variable "billing_contact" {
  type = object({
    name  = string
    title = string
    email = string
    phone = string
  })
  description = "Billing alternate contact. Set to null to skip. All fields are required when set."
  default     = null
}

variable "operations_contact" {
  type = object({
    name  = string
    title = string
    email = string
    phone = string
  })
  description = "Operations alternate contact. Set to null to skip. All fields are required when set."
  default     = null
}

variable "security_contact" {
  type = object({
    name  = string
    title = string
    email = string
    phone = string
  })
  description = "Security alternate contact. Set to null to skip. All fields are required when set."
  default     = null
}

// env vars

variable "account_id" {
  type        = string
  description = "Target account id where the alternate contacts should be set"
}

variable "assume_role_name" {
  type        = string
  description = "The name of the role to assume in target account identified by account_id"
}

variable "aws_partition" {
  type        = string
  description = "The AWS partition to use. e.g. aws, aws-cn, aws-us-gov"
  default     = "aws"
}
