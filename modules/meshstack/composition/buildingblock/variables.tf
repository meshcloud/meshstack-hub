variable "name" {
  type        = string
  description = "Name used for the building block definition and building block this composition creates."
}

variable "workspace_identifier" {
  type        = string
  description = "Workspace the created building block definition is owned by and the created building block is attached to. Wired in as a WORKSPACE_IDENTIFIER input, so it is always the consuming workspace — the same one the run's ephemeral API key is scoped to."
}

variable "link_url" {
  type        = string
  description = "Target of the link the created building block publishes."
}

variable "hub_git_ref" {
  type        = string
  description = "Hub reference the created building block definition clones its implementation from. Wired in as a static input from the composition's own `var.hub.git_ref`, so both definitions stay on the same hub revision."
}
