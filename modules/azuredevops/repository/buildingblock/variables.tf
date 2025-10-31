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
  description = "Azure DevOps Project ID where the repository will be created"
  type        = string
}

variable "repository_name" {
  description = "Name of the Git repository to create"
  type        = string
}

variable "init_type" {
  description = "Type of repository initialization. Options: Clean, Import, Uninitialized"
  type        = string
  default     = "Clean"

  validation {
    condition     = contains(["Clean", "Import", "Uninitialized"], var.init_type)
    error_message = "init_type must be one of: Clean, Import, Uninitialized"
  }
}

variable "enable_branch_policies" {
  description = "Enable branch protection policies on the default branch"
  type        = bool
  default     = true
}

variable "minimum_reviewers" {
  description = "Minimum number of reviewers required for pull requests"
  type        = number
  default     = 2

  validation {
    condition     = var.minimum_reviewers >= 1 && var.minimum_reviewers <= 10
    error_message = "minimum_reviewers must be between 1 and 10"
  }
}
