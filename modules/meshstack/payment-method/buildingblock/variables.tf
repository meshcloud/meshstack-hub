variable "payment_method_name" {
  type        = string
  description = "Name of the payment method"
  default     = "default-payment-method"
}

variable "workspace_id" {
  type        = string
  description = "The ID of the workspace to which this payment method will be assigned"
}

variable "amount" {
  type        = number
  description = "The budget amount for this payment method"
}

variable "expiration_date" {
  type        = string
  description = "The expiration date of the payment method in RFC3339 format (e.g., '2025-12-31')"
  default     = null
}

variable "tags" {
  type        = map(list(string))
  description = "Additional tags to apply to the payment method"
  default     = {}
}

variable "approval" {
  type = bool
  description = "Payment method validation"
}
