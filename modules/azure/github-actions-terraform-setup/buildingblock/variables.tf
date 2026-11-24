variable "repo_name" {
  type        = string
  description = "Name of the repository to connect."
}

variable "workspace_identifier" {
  type = string
}

variable "project_identifier" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}
