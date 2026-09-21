variable "azuredevops_base_url" {
  type        = string
  default     = "https://dev.azure.com"
  description = "Base URL of the Azure DevOps instance. Override for Azure DevOps Server."
}

variable "azuredevops_organization" {
  type        = string
  description = "Azure DevOps organization name, as it appears in the URL after the base URL."
}

variable "azuredevops_personal_access_token" {
  type        = string
  sensitive   = true
  description = "Personal access token used to commit the pipeline file. Needs Code (Read & write) on the repository below."
}

variable "azuredevops_repository_id" {
  type        = string
  description = "UUID of the Azure DevOps Git repository holding the pipeline file. Found under Project settings → Repositories → the repository, as the `repo` query parameter."
}

variable "azuredevops_ref_name" {
  type        = string
  default     = "refs/heads/main"
  description = "Full git ref the pipeline file is committed to and the pipeline runs on, for example 'refs/heads/main'. The branch must already exist — this backplane commits onto it, it does not create it."

  validation {
    condition     = startswith(var.azuredevops_ref_name, "refs/")
    error_message = "azuredevops_ref_name must be a full git ref, for example 'refs/heads/main'."
  }
}

variable "azuredevops_pipeline_yaml_path" {
  type        = string
  default     = "azure-pipelines.yml"
  description = "Repository path the pipeline file is committed to. Must match the YAML path the pipeline definition was created with — Azure DevOps reads that path and nothing else."
}
