variable "project_name" {
  description = "Azure DevOps Project Name where the repository will be created"
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
  default     = 1

  validation {
    condition     = var.minimum_reviewers >= 1 && var.minimum_reviewers <= 10
    error_message = "minimum_reviewers must be between 1 and 10"
  }
}
