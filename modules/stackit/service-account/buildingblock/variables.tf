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

variable "automation_service_account_email" {
  type        = string
  nullable    = false
  description = "Email of the service account this run acts as. It grants itself `editor` on the project to create federations."
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "Workspace that owns the federated building block definitions."
}

variable "federated_building_block_definitions" {
  type        = list(string)
  nullable    = false
  description = "UUIDs of building block definitions whose runs may act as this service account via WIF."
}
