variable "budget_name" {
  type        = string
  description = "Name of the budget alert rule"
  default     = "budget_alert"
}

variable "contact_emails" {
  type        = list(string)
  nullable    = false
  description = "Email addresses of the users who should receive the budget alert, e.g. [\"foo@example.com\", \"bar@example.com\"]."

  validation {
    condition     = length(var.contact_emails) > 0
    error_message = "contact_emails must hold at least one email address."
  }

  validation {
    condition     = alltrue([for email in var.contact_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    error_message = "Every entry in contact_emails must look like an email address, e.g. foo@example.com."
  }
}

variable "monthly_budget_amount" {
  type        = number
  description = "Set the monthly budget for this account in USD."
}

variable "actual_threshold_percent" {
  type        = number
  description = "The precise percentage of the monthly budget at which you wish to activate the alert upon reaching. E.g. '15' for 15% or '120' for 120%"
  default     = 80
}

variable "forecasted_threshold_percent" {
  type        = number
  description = "The forecasted percentage of the monthly budget at which you wish to activate the alert upon reaching. E.g. '15' for 15% or '120' for 120%"
  default     = 100
}

// env vars

variable "account_id" {
  description = "target account id where the budget alert should be created"
  type        = string
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