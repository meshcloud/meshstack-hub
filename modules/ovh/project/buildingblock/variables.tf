variable "endpoint" {
  type        = string
  nullable    = false
  description = "OVHcloud API endpoint, e.g. `ovh-eu`, `ovh-ca` or `ovh-us`."
}

variable "role_mapping" {
  type        = map(list(string))
  nullable    = false
  description = "Maps each meshStack role to the OVHcloud IAM actions its members get on the project, e.g. `publicCloudProject:apiovh:*`. Unknown meshStack roles in `users` are ignored."
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "meshStack workspace identifier. The project is described as `<workspace_identifier>-<project_identifier>`."
}

variable "project_identifier" {
  type        = string
  nullable    = false
  description = "meshStack project identifier. The project is described as `<workspace_identifier>-<project_identifier>`."
}

variable "users" {
  description = "List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to OVHcloud IAM actions via `role_mapping`."
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  nullable = false
}
