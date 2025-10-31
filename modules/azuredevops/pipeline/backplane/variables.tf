variable "azure_devops_organization_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)"
  type        = string
}

variable "service_principal_name" {
  description = "Name for the Azure DevOps service principal"
  type        = string
  default     = "azure-devops-terraform"
}

variable "key_vault_name" {
  description = "Name of the Key Vault to store the Azure DevOps PAT"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name for the Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
}

variable "scope" {
  description = "Azure scope for role definitions (subscription or management group)"
  type        = string
}
