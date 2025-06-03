variable "billing_account_id" {
  description = "The ID of the billing account to which the budget will be applied"
  type        = string
}

variable "backplane_project_id" {
  description = "The project ID where the backplane resources will be created"
  type        = string
}

variable "project_id" {
  description = "The GCP project ID where the budget will be created"
  type        = string
}

variable "budget_name" {
  description = "Display name for the budget"
  type        = string
}

variable "monthly_budget_amount" {
  description = "The budget amount in the project's billing currency"
  type        = number
}

variable "budget_currency" {
  description = "The currency for the budget amount, e.g., EUR"
  type        = string
  default     = "EUR"
}

variable "contact_email" {
  description = "email address to receive budget alerts"
  type        = string
}

variable "alert_thresholds_yaml" {
  description = "YAML string defining alert thresholds with fields threshold_percent and spend_basis"
  type        = string
  default     = <<EOT
- percent: 80
  basis: ACTUAL
- percent: 100
  basis: FORECASTED
EOT

}
