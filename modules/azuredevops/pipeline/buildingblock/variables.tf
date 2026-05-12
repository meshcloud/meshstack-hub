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

variable "repository_name" {
  description = "Name of the repository, used as the namespace name in the generated pipeline YAML"
  type        = string
}

variable "service_connection_name" {
  description = "Name of the Azure DevOps service connection for AKS access"
  type        = string
}

variable "agent_pool_name" {
  description = "Name of the Azure DevOps agent pool to run the pipeline on"
  type        = string
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
