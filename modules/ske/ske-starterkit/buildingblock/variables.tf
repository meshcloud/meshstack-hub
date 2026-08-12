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

variable "platform_ref" {
  type = object({
    uuid = string
    kind = optional(string, "meshPlatform")
  })
  description = "Reference (by uuid) to the meshPlatform the tenants are created on. Wired in as a static building block input from the platform/backplane that owns the meshPlatform (its `.ref` output). Required because the meshTenant v4 API references platforms by ref."
}

variable "landing_zone_refs" {
  type        = map(object({ name = string, kind = optional(string, "meshLandingZone") }))
  description = "Landing zone references keyed by stage (usually dev and prod). Wired in as a static building block input from the platform/backplane that owns the meshLandingZones (their `.ref` outputs)."
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

variable "dns_zone_name" {
  type        = string
  description = "DNS zone name used for application ingress hostnames."
}

variable "add_random_name_suffix" {
  type        = bool
  description = "Whether to append a random suffix to the provided name for shared environments."
}

variable "building_block_definition_version_refs" {
  # meshStack passes this map as a static building block input; the matching input in
  # meshstack_integration.tf of the parent module carries the same name.
  type = map(object({
    uuid = string
  }))
  description = "Building block definition version references for the child building blocks this starter kit creates, keyed by definition name (`git-repository` and `forgejo-connector`). The definition uuid is not part of this map, because meshStack derives the definition of a parent building block from the building block ref."
}
