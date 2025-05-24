variable "budget_name" {
  type        = string
  description = "Name of the budget alert rule"
  default     = "budget_alert"
}

variable "contact_emails" {
  type        = string
  description = "Comma-separated list of emails of the users who should receive the Budget alert. e.g. 'foo@example.com, bar@example.com'"
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