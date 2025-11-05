variable "service_principal_name" {
  description = "Name of the service principal for Azure DevOps agent pool management"
  type        = string
  default     = "sp-azure-devops-agent-pool"
}

variable "key_vault_name" {
  description = "Name of the Key Vault to store Azure DevOps PAT"
  type        = string

  validation {
    condition     = length(var.key_vault_name) >= 3 && length(var.key_vault_name) <= 24
    error_message = "Key Vault name must be between 3 and 24 characters."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group for Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "scope" {
  description = "Scope for the custom role definition (e.g., subscription ID)"
  type        = string
}
