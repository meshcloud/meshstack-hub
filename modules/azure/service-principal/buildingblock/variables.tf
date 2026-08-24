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
  description = "Azure RBAC built-in role name to assign to the service principal (e.g., 'Contributor', 'Reader', 'Storage Blob Data Reader'). Ignored if custom_role is specified."
  type        = string
  default     = null
}

variable "custom_role" {
  description = "Define a custom role instead of using a built-in role. If specified, azure_role is ignored."
  type = object({
    name             = string
    description      = optional(string, "Custom role managed by Terraform")
    actions          = optional(list(string), [])
    not_actions      = optional(list(string), [])
    data_actions     = optional(list(string), [])
    not_data_actions = optional(list(string), [])
  })
  default = null

  validation {
    # try() guards the attribute access: the Terraform version the runner pins evaluates both
    # operands of || even when the left one already decides the result, so a null custom_role
    # faulted here with "Attempt to get attribute from null value" and no building block could
    # ever apply. actions and data_actions default to [] whenever custom_role itself is set.
    condition     = var.custom_role == null || try(length(var.custom_role.actions) + length(var.custom_role.data_actions) > 0, false)
    error_message = "custom_role must have at least one action or data_action defined"
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
