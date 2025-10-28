variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "region" {
  type        = string
  default     = "eu30"
  description = "The region of the subaccount."
}

variable "project_identifier" {
  type        = string
  description = "The meshStack project identifier."
}

variable "subfolder" {
  type        = string
  description = "The subfolder to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit."
}

# note: these permissions are passed in from meshStack and automatically updated whenever something changes
# atm. we are not using them inside this building block implementation, but they give us a trigger to often reconcile
# the permissions
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
  type = list(object({
    service_name = string
    plan_name    = string
    amount       = optional(number)
  }))
  description = "List of entitlements to assign to the subaccount. For quota-based services, specify 'amount'. For multitenant applications (category APPLICATION), omit 'amount' or set to null. Entitlements must be configured before subscriptions can be created."
  default     = []
}

variable "subscriptions" {
  type = list(object({
    app_name   = string
    plan_name  = string
    parameters = optional(map(string), {})
  }))
  description = "List of application subscriptions to create in the subaccount (e.g., SAP Build Code, Process Automation)."
  default     = []
}

variable "cloudfoundry_instance" {
  type = object({
    name        = optional(string, "cf-instance")
    environment = optional(string, "cloudfoundry")
    plan_name   = string
    parameters  = optional(map(string), {})
  })
  description = "Configuration for Cloud Foundry environment instance. Set to null to skip creation."
  default     = null
}

variable "trust_configuration" {
  type = object({
    identity_provider = string
  })
  description = "Trust configuration for external Identity Provider (e.g., SAP IAS). Set to null to skip configuration. Only identity_provider is required; origin and other attributes are computed."
  default     = null
}
