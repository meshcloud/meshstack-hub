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

    owner_tag_key = optional(string, null)
  })
  description = "Tags for dev/prod meshProject."
}

variable "repo_clone_addr" {
  type        = string
  description = "URL to clone into the starterkit git repository."
}

variable "building_block_definition_version_refs" {
  type = map(object({ uuid = string }))
}

variable "git_repository_definition_uuid" {
  type        = string
  description = "Definition UUID of the composed git-repository building block."
}
