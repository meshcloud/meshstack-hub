variable "project_name" {
  description = "Name of the Azure DevOps project"
  type        = string

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 64
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
    boards       = optional(string, "enabled")
    repositories = optional(string, "enabled")
    pipelines    = optional(string, "enabled")
    testplans    = optional(string, "disabled")
    artifacts    = optional(string, "enabled")
  })
  default = {
    boards       = "enabled"
    repositories = "enabled"
    pipelines    = "enabled"
    testplans    = "enabled"
    artifacts    = "enabled"
  }
}

variable "users" {
  description = "List of users from authoritative system"
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
}

variable "repository_name" {
  description = "Name of the Git repository to create"
  type        = string
}

variable "minimum_reviewers" {
  description = "Minimum number of reviewers required for pull requests"
  type        = number
  default     = 1

  validation {
    condition     = var.minimum_reviewers >= 1 && var.minimum_reviewers <= 10
    error_message = "minimum_reviewers must be between 1 and 10"
  }
}

variable "enable_branch_policies" {
  description = "Enable branch protection policies on the default branch"
  type        = bool
  default     = true
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
