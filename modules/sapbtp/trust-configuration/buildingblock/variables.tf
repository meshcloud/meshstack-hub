variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "subaccount_id" {
  type        = string
  description = "The ID of the subaccount where trust configuration should be added."
}

variable "identity_provider" {
  type        = string
  default     = ""
  description = "Custom identity provider origin (e.g., mytenant.accounts.ondemand.com). Leave empty to skip trust configuration."
}
