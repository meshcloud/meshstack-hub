# Every variable here is passed straight through to `./this`, which is where the descriptions and
# the validation rules live, next to the code that uses them. They are repeated here only because
# Terraform has no way to forward a child module's variable declarations, and the building block
# definition's input contract is this file. Keep the two in step: an input added in `./this` is not
# orderable until it is added here too.

variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}

variable "landing_zone" {
  type     = string
  nullable = false
}

variable "workspace_identifier" {
  type     = string
  nullable = false
}

variable "platform_ref" {
  type = object({
    uuid = string
    kind = string
  })
  nullable = false
}

variable "landing_zone_refs" {
  type = map(object({
    name = string
    kind = string
  }))
  nullable = false
}

# The only variable here that keeps a default. The definition declares this input only where a spoke
# network can be created, so with networking off no value arrives at all.
variable "network" {
  type = object({
    prefix_length    = number
    ipv4_nameservers = list(string)
  })
  default = null
}

variable "network_static" {
  type = object({
    matching_landing_zones = set(string)
    bbd_version_ref        = object({ uuid = string })
  })
  nullable = false
}

variable "tags" {
  type = object({
    project               = map(list(string))
    project_owner_tag_key = string
  })
  nullable = false
}

variable "add_random_name_suffix" {
  type     = bool
  nullable = false
}

# Written by the runner, not by the definition's inputs: it is the uuid of the building block this run
# belongs to. `terraform_data.self_purge` uses it to delete that block once the starterkit is done.
variable "meshstack_building_block_id" {
  type     = string
  nullable = false
}
