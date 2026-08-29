# Defaulted, unlike the other inputs, so that a run can still destroy a building block whose stored
# inputs predate a rename of this one. A destroy only has to delete the created meshObjects, and their
# display names have no bearing on that.
variable "link_name" {
  type        = string
  default     = "Link"
  description = "Name given to the building block definition and building block this composition creates."
}

variable "link_url" {
  type        = string
  description = "Target of the link the created building block publishes."
}

variable "workspace_identifier" {
  type        = string
  description = "Workspace the created building block definition is owned by and the created building block is attached to. Wired in as a WORKSPACE_IDENTIFIER input, so it is always the consuming workspace — the same one the run's ephemeral API key is scoped to."
}

variable "hub_git_ref" {
  type        = string
  description = "Hub reference the created building block definition clones its implementation from. Wired in as a static input from the composition's own `var.hub.git_ref`, so both definitions stay on the same hub revision."
}

variable "platform_name" {
  type        = string
  default     = "Composition Demo Platform"
  description = "Display name of the platform this composition creates. Its identifier is generated instead of taken from here, because a platform identifier cannot be reused once deleted."
}

variable "building_block_uuid" {
  type        = string
  description = "UUID of the building block this run belongs to. Wired in as a TENANT_BUILDING_BLOCK_UUID input and used to name the created platform, location and platform type, whose identifiers must be globally unique."
}
