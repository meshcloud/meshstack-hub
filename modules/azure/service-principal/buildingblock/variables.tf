variable "display_name" {
  description = "Display name for the Entra ID application and service principal"
  type        = string
}

variable "description" {
  description = "Description for the Entra ID application"
  type        = string
  default     = "Service principal managed by Terraform"
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID where role assignments will be created"
  type        = string
}

variable "azure_role" {
  description = "Azure RBAC role to assign to the service principal on the subscription"
  type        = string
  default     = "Contributor"

  validation {
    condition     = contains(["Owner", "Contributor", "Reader"], var.azure_role)
    error_message = "azure_role must be one of: Owner, Contributor, Reader"
  }
}

variable "create_client_secret" {
  description = "Whether to create a client secret for the service principal (set to false for workload identity federation)"
  type        = bool
  default     = true
}

variable "secret_rotation_days" {
  description = "Number of days before the service principal secret expires (only used if create_client_secret is true)"
  type        = number
  default     = 90

  validation {
    condition     = var.secret_rotation_days >= 30 && var.secret_rotation_days <= 730
    error_message = "secret_rotation_days must be between 30 and 730 days"
  }
}

variable "owners" {
  description = "List of object IDs to set as owners of the application (defaults to current user)"
  type        = list(string)
  default     = []
}
