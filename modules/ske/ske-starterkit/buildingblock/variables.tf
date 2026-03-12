variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  description = "Information about the creator of the resources who will be assigned Project Admin role"
}

variable "name" {
  type        = string
  description = "This name will be used for the created projects."
}

variable "workspace_identifier" {
  type = string
}

variable "full_platform_identifier" {
  type        = string
  description = "Full platform identifier of the SKE platform."
}

variable "landing_zone_identifiers" {
  type = object({
    dev  = string
    prod = string
  })
  description = "SKE Landing zone identifiers for the dev/prod meshTenant."
}

variable "project_tags" {
  type = object({
    dev : map(list(string))
    prod : map(list(string))
  })
  description = "Tags for dev/prod meshProject."
}

variable "git_repository_template_repo_path" {
  type        = string
  description = "Template repository path (owner/name) used for starterkit git repository creation."
}

variable "building_block_definition_version_refs" {
  type = map(object({
    kind = string
    uuid = string
  }))
}