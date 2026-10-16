variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID (existing project) in which the service account will be created."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the STACKIT service account to create. Must be unique within the project."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  description = "STACKIT project roles to grant the service account within the project (e.g. \"reader\", \"editor\")."
}

variable "federation_backplane_email" {
  type        = string
  nullable    = false
  description = "Email of the backplane service account of the STACKIT Service Account Federation definition. It gets the `editor` role on the project, so a federation building block can federate the service account."
}
