locals {
  contact_emails_list = [
    for x in split(",", var.contact_emails) : trimspace(x)
  ]
}

# AWS requires a startdate, we use time_static to ensure the date doesn't change on subsequent applies
resource "time_static" "start_date" {
}

data "aws_caller_identity" "current" {}

resource "aws_budgets_budget" "account_budget" {
  name              = var.budget_name
  budget_type       = "COST"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", time_static.start_date.rfc3339)
  limit_amount      = var.monthly_budget_amount
  limit_unit        = "USD"

  notification {
    comparison_operator        = "EQUAL_TO"
    threshold                  = var.actual_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = local.contact_emails_list
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.forecasted_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = local.contact_emails_list
  }
}
