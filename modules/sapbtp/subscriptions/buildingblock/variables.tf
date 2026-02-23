variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "subaccount_id" {
  type        = string
  description = "The ID of the subaccount where subscriptions should be added."
}

variable "subscriptions" {
  type        = string
  default     = ""
  description = "Comma-separated list of application subscriptions in format: app.plan (e.g., 'build-workzone.standard,integrationsuite.enterprise_agreement')"
}
