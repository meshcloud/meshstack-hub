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
  description = "Azure DevOps Project ID where the pipeline will be created"
  type        = string
}

variable "pipeline_name" {
  description = "Name of the pipeline to create"
  type        = string
}

variable "repository_type" {
  description = "Type of repository. Options: TfsGit, GitHub, GitHubEnterprise, Bitbucket"
  type        = string
  default     = "TfsGit"

  validation {
    condition     = contains(["TfsGit", "GitHub", "GitHubEnterprise", "Bitbucket"], var.repository_type)
    error_message = "repository_type must be one of: TfsGit, GitHub, GitHubEnterprise, Bitbucket"
  }
}

variable "repository_id" {
  description = "Repository ID or name where the pipeline YAML file is located"
  type        = string
}

variable "branch_name" {
  description = "Default branch for the pipeline"
  type        = string
  default     = "refs/heads/main"
}

variable "yaml_path" {
  description = "Path to the YAML pipeline definition file in the repository"
  type        = string
  default     = "azure-pipelines.yml"
}

variable "variable_group_ids" {
  description = "List of variable group IDs to link to this pipeline"
  type        = list(number)
  default     = []
}

variable "pipeline_variables" {
  description = "List of pipeline variables to create"
  type = list(object({
    name           = string
    value          = string
    is_secret      = optional(bool, false)
    allow_override = optional(bool, true)
  }))
  default = []
}
