variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "region" {
  type        = string
  default     = "eu10"
  description = "The region of the subaccount."
}

variable "project_identifier" {
  type        = string
  description = "The meshStack project identifier."
}

variable "subfolder" {
  type        = string
  default     = ""
  description = "The subfolder to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit."
}

variable "users" {
  type = list(object(
    {
      meshIdentifier = string
      username       = string
      firstName      = string
      lastName       = string
      email          = string
      euid           = string
      roles          = list(string)
    }
  ))
  description = "Users and their roles provided by meshStack"
  default     = []
}

variable "entitlements" {
  type        = string
  default     = ""
  description = "Comma-separated list of service entitlements in format: service.plan (e.g., 'postgresql-db.trial,destination.lite,xsuaa.application')"
}

variable "subscriptions" {
  type        = string
  default     = ""
  description = "Comma-separated list of application subscriptions in format: app.plan (e.g., 'build-workzone.standard,integrationsuite.enterprise_agreement')"
}

variable "enable_cloudfoundry" {
  type        = bool
  default     = false
  description = "Enable Cloud Foundry environment in the subaccount"
}

variable "cloudfoundry_plan" {
  type        = string
  default     = "standard"
  description = "Cloud Foundry environment plan (standard or trial)"
}

variable "cloudfoundry_space_name" {
  type        = string
  default     = "dev"
  description = "Name for the Cloud Foundry space"
}

variable "cf_services" {
  type        = string
  default     = ""
  description = "Comma-separated list of Cloud Foundry service instances in format: service.plan (e.g., 'postgresql.small,destination.lite,redis.medium')"
}

variable "identity_provider" {
  type        = string
  default     = ""
  description = "Custom identity provider origin (e.g., mytenant.accounts.ondemand.com). Leave empty to skip trust configuration."
}
