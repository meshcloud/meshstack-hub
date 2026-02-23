variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "subaccount_id" {
  type        = string
  description = "The ID of the subaccount where entitlements should be added."
}

variable "entitlements" {
  type        = string
  default     = ""
  description = "Comma-separated list of service entitlements in format: service.plan (e.g., 'postgresql-db.trial,destination.lite,xsuaa.application')"
}
