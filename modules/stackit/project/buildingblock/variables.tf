variable "parent_container_id" {
  type        = string
  nullable    = false
  description = "The parent container ID (organization or folder) where the project will be created."
}

variable "environment" {
  type        = string
  default     = null
  description = "The environment type (production, staging, development). If not set, uses parent_container_id directly."
}

variable "parent_container_ids" {
  type = object({
    production  = optional(string)
    staging     = optional(string)
    development = optional(string)
  })
  default     = {}
  description = "Parent container IDs for different environments. If environment is set, the corresponding container ID will be used."
}

variable "project_name" {
  type        = string
  nullable    = false
  description = "The name of the StackIt project to create."
}

variable "service_account_email" {
  type        = string
  nullable    = false
  description = "Email of the STACKIT service account for WIF-based authentication and project ownership."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels to apply to the project. Use 'networkArea' to specify the STACKIT Network Area."
}

variable "users" {
  description = "List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to STACKIT project roles via `role_mapping`."
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  default = []
}

variable "role_mapping" {
  type        = map(list(string))
  description = "Maps meshStack roles from `users[*].roles` to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names. Unknown meshStack roles are ignored."

  default = {
    admin  = ["owner"]
    user   = ["editor"]
    reader = ["reader"]
  }
}

