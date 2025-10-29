variable "repo_description" {
  type        = string
  default     = "created by github-repo-building-block"
  description = "Description of the GitHub repository"
}

variable "repo_name" {
  type        = string
  default     = "github-repo"
  description = "Name of the GitHub repository"
}

variable "repo_visibility" {
  type        = string
  default     = "private"
  description = "Visibility of the GitHub repository"
}

variable "template_owner" {
  type        = string
  default     = "template-owner"
  description = "Owner of the template repository"
}

variable "template_repo" {
  type        = string
  default     = "github-repo"
  description = "Name of the template repository"
}

variable "use_template" {
  type        = bool
  description = "Flag to indicate whether to create a repo based on a Template Repository"
  default     = false
}

variable "repo_owner" {
  type        = string
  default     = null
  description = "Username of the GitHub user who will be set as the owner/admin of the repository. If not set, no collaborator will be added."
}
