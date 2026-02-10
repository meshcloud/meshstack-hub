variable "workspace_identifier" {
  type        = string
  description = "meshStack workspace identifier"
}

variable "name" {
  type        = string
  description = "This name will be used for the created projects, app subdomain, Azure DevOps project and repository."
}

variable "full_platform_identifier" {
  type        = string
  description = "Full platform identifier of the AKS Namespace platform."
}

variable "landing_zone_dev_identifier" {
  type        = string
  description = "AKS Landing zone identifier for the development tenant."
}

variable "landing_zone_prod_identifier" {
  type        = string
  description = "AKS Landing zone identifier for the production tenant."
}

variable "azdevops_project_definition_version_uuid" {
  type        = string
  description = "UUID of the Azure DevOps project building block definition version."
}

variable "azdevops_project_definition_uuid" {
  type        = string
  description = "UUID of the Azure DevOps project building block definition."
}

variable "azdevops_repository_definition_version_uuid" {
  type        = string
  description = "UUID of the Azure DevOps repository building block definition version."
}

variable "azdevops_repository_definition_uuid" {
  type        = string
  description = "UUID of the Azure DevOps repository building block definition."
}

variable "azdevops_pipeline_definition_version_uuid" {
  type        = string
  description = "UUID of the Azure DevOps pipeline building block definition version."
}

variable "azdevops_pipeline_definition_uuid" {
  type        = string
  description = "UUID of the Azure DevOps pipeline building block definition."
}

variable "azdevops_service_connection_definition_version_uuid" {
  type        = string
  description = "UUID of the Azure DevOps service connection building block definition version."
}

variable "azdevops_service_connection_definition_uuid" {
  type        = string
  description = "UUID of the Azure DevOps service connection building block definition."
}

variable "azdevops_organization_name" {
  type        = string
  description = "Azure DevOps organization name. Used only for display purposes."
}

variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  description = "Information about the creator of the resources who will be assigned Project Admin role"
}

variable "project_tags_yaml" {
  type        = string
  description = <<EOF
YAML configuration for project tags that will be applied to dev and prod projects. Expected structure:

```yaml
dev:
  key1:
    - "value1"
    - "value2"
  key2:
    - "value3"
prod:
  key1:
    - "value4"
  key2:
    - "value5"
    - "value6"
```
EOF
  default     = <<EOF
dev: {}
prod: {}
EOF

  validation {
    condition     = can(yamldecode(var.project_tags_yaml))
    error_message = "project_tags_yaml must be valid YAML"
  }

  validation {
    condition     = can(yamldecode(var.project_tags_yaml).dev) && yamldecode(var.project_tags_yaml).dev != null
    error_message = "dev section is required in project_tags_yaml"
  }

  validation {
    condition     = can(yamldecode(var.project_tags_yaml).prod) && yamldecode(var.project_tags_yaml).prod != null
    error_message = "prod section is required in project_tags_yaml"
  }
}

variable "repository_init_type" {
  type        = string
  description = "Repository initialization type (Clean or Import)"
  default     = "Clean"

  validation {
    condition     = contains(["Clean", "Import"], var.repository_init_type)
    error_message = "repository_init_type must be either 'Clean' or 'Import'"
  }
}

variable "enable_branch_policies" {
  type        = bool
  description = "Enable branch policies for the main branch (minimum reviewers, work item linking)"
  default     = true
}

variable "minimum_reviewers" {
  type        = number
  description = "Minimum number of reviewers required for pull requests"
  default     = 1

  validation {
    condition     = var.minimum_reviewers >= 0 && var.minimum_reviewers <= 10
    error_message = "minimum_reviewers must be between 0 and 10"
  }
}

variable "dev_azure_subscription_id" {
  type        = string
  description = "Azure subscription ID for the development environment"
}

variable "dev_service_principal_id" {
  type        = string
  description = "Service principal client ID for the development environment"
}

variable "dev_application_object_id" {
  type        = string
  description = "Azure AD application object ID for the development service principal"
}

variable "prod_azure_subscription_id" {
  type        = string
  description = "Azure subscription ID for the production environment"
}

variable "prod_service_principal_id" {
  type        = string
  description = "Service principal client ID for the production environment"
}

variable "prod_application_object_id" {
  type        = string
  description = "Azure AD application object ID for the production service principal"
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}
