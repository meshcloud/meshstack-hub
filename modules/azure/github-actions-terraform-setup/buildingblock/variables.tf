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

variable "deploy_role_definition_id" {
  type        = string
  description = "Role definition ID to assign to the GitHub Actions App Service Managed Identity. This is used to deploy resources via Terraform."
}
