variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the service account lives in."
}

variable "service_account_email" {
  type        = string
  nullable    = false
  description = "Email of the STACKIT service account to federate."
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
  description = "UUIDs of building block definitions whose runs may act as the service account."
}
