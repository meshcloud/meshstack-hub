variable "namespace" {
  description = "Associated namespace in AKS."
  type        = string
}

variable "github_repo" {
  description = "The GitHub repository to be connected."
  type        = string
}

variable "github_branch" {
  description = "The branch of the GitHub repository to be used."
  type        = string
}
