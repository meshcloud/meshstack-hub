variable "service_principal_name" {
  description = "Name of the service principal for VMSS runner management"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault for storing secrets"
  type        = string
}

variable "location" {
  description = "Azure region for the Key Vault"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for the Key Vault"
  type        = string
}

variable "azuredevops_pat" {
  description = "Azure DevOps Personal Access Token for agent registration"
  type        = string
  sensitive   = true
}

variable "azuredevops_pat_secret_name" {
  description = "Name of the secret in Key Vault for storing the Azure DevOps PAT"
  type        = string
  default     = "azuredevops-pat"
}
