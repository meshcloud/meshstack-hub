variable "deploy_role_definition_id" {
  type        = string
  description = "Role definition ID to assign to the GitHub Actions App Service Managed Identity. This is used to deploy resources via Terraform."
}
