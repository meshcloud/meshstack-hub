variable "azure_devops_organization_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Key Vault containing the Azure DevOps PAT"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the Key Vault"
  type        = string
}

variable "pat_secret_name" {
  description = "Name of the secret in Key Vault that contains the Azure DevOps PAT"
  type        = string
  default     = "azdo-pat"
}

variable "project_id" {
  description = "Azure DevOps Project ID where the service connection will be created"
  type        = string
}

variable "service_connection_name" {
  description = "Name of the service connection to create"
  type        = string
}

variable "description" {
  description = "Description for the service connection"
  type        = string
  default     = "Azure subscription service connection managed by Terraform"
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID to connect to"
  type        = string
}

variable "service_principal_id" {
  description = "Client ID of the existing Azure AD service principal"
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
}

variable "authorize_all_pipelines" {
  description = "Automatically authorize all pipelines to use this service connection"
  type        = bool
  default     = false
}

variable "application_id" {
  description = "Azure AD Application client ID (GUID) for federated identity credential"
  type        = string
}
