variable "subscription_id" {
  type        = string
  nullable    = false
  description = "The Azure subscription the endpoint is created in, the tenant's landing zone."
}

variable "location" {
  type        = string
  nullable    = false
  description = "The Azure region of the AI Services account. Every model in `models` must be available there for `deployment_sku`."
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name prefix of the resource group and the AI Services account. A random 5-character suffix is appended to the account for global uniqueness of its subdomain."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name))
    error_message = "3 to 22 characters: lowercase letters, digits and dashes, starting with a letter and ending with a letter or digit."
  }
}

variable "models" {
  type = map(object({
    format  = optional(string, "OpenAI")
    version = string
  }))
  nullable    = false
  description = "Models the platform team allows, keyed by model name. Set by the platform team, the application team picks one of the keys as `model_name`."
}

variable "model_name" {
  type        = string
  nullable    = false
  description = "The model to deploy, one of the keys of `models`."
  validation {
    condition     = contains(keys(var.models), var.model_name)
    error_message = "The model is not one the platform team allows."
  }
}

variable "deployment_sku" {
  type        = string
  default     = "DataZoneStandard"
  description = "Deployment type of the model. `DataZoneStandard` keeps inference inside the data zone of the region (EU or US), `Standard` inside the region itself, `GlobalStandard` routes it worldwide."
  validation {
    condition     = contains(["Standard", "DataZoneStandard", "GlobalStandard"], var.deployment_sku)
    error_message = "Must be Standard, DataZoneStandard or GlobalStandard."
  }
}

variable "capacity" {
  type        = number
  default     = 10
  description = "Rate limit of the deployment in thousands of tokens per minute. It is taken from the subscription's quota for the model, region and deployment type."
  validation {
    condition     = var.capacity >= 1 && var.capacity <= 1000 && floor(var.capacity) == var.capacity
    error_message = "Must be a whole number between 1 and 1000."
  }
}

variable "app_principal_id" {
  type        = string
  default     = null
  description = "Object ID of the identity the application calls the model with, such as a managed identity. It is granted `Cognitive Services OpenAI User` on the account. Null grants nothing."
  validation {
    condition     = var.app_principal_id == null || can(regex("^[0-9a-fA-F-]{36}$", var.app_principal_id))
    error_message = "Must be an object ID (GUID)."
  }
}
