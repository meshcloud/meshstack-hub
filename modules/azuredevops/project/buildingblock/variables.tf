variable "azure_devops_organization_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Key Vault containing the Azure DevOps PAT"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name containing the Key Vault"
  type        = string
}

variable "project_name" {
  description = "Name of the Azure DevOps project"
  type        = string
  
  validation {
    condition     = length(var.project_name) >= 1 && length(var.project_name) <= 64
    error_message = "Project name must be between 1 and 64 characters."
  }
}

variable "project_description" {
  description = "Description of the Azure DevOps project"
  type        = string
  default     = "Managed by Terraform"
}

variable "project_visibility" {
  description = "Visibility of the project (private or public)"
  type        = string
  default     = "private"
  
  validation {
    condition     = contains(["private", "public"], var.project_visibility)
    error_message = "Project visibility must be either 'private' or 'public'."
  }
}

variable "work_item_template" {
  description = "Work item process template"
  type        = string
  default     = "Agile"
  
  validation {
    condition     = contains(["Agile", "Basic", "CMMI", "Scrum"], var.work_item_template)
    error_message = "Work item template must be one of: Agile, Basic, CMMI, Scrum."
  }
}

variable "version_control" {
  description = "Version control system for the project"
  type        = string
  default     = "Git"
  
  validation {
    condition     = contains(["Git", "Tfvc"], var.version_control)
    error_message = "Version control must be either 'Git' or 'Tfvc'."
  }
}

variable "project_features" {
  description = "Project features to enable/disable"
  type = object({
    boards      = optional(string, "enabled")
    repositories = optional(string, "enabled")  
    pipelines   = optional(string, "enabled")
    testplans   = optional(string, "disabled")
    artifacts   = optional(string, "enabled")
  })
  default = {}
}

variable "users" {
  description = "List of users with their permissions and license types"
  type = list(object({
    principal_name = string # Email address or UPN
    role          = string # "reader", "contributor", "administrator"
    license_type   = optional(string, "stakeholder") # "stakeholder", "basic", "advanced"
  }))
  default = []
  
  validation {
    condition = alltrue([
      for user in var.users : contains(["reader", "contributor", "administrator"], user.role)
    ])
    error_message = "User role must be one of: reader, contributor, administrator."
  }
  
  validation {
    condition = alltrue([
      for user in var.users : contains(["stakeholder", "basic", "advanced"], user.license_type)
    ])
    error_message = "User license_type must be one of: stakeholder, basic, advanced."
  }
}

variable "create_custom_groups" {
  description = "Whether to create custom groups for role-based access"
  type        = bool
  default     = true
}