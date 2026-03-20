variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the service account will be created."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID where the service account will be granted permissions to create and manage projects."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-project"
  nullable    = false
  description = "Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}
