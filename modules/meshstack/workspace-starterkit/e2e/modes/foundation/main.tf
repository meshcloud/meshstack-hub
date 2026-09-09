variable "test_context" {
  type = object({
    workspace = string

    # Must match the `hub.bbd_draft` the definition was deployed with: a draft has no released
    # version to order against.
    bbd_draft = bool
  })
  nullable = false
}

# Unused: the root pipes one argument list to both modes, and neither argument can change a
# definition that is already published.
variable "ttl_optional" {
  type = any
}

data "meshstack_building_block_definitions" "published" {
  workspace_identifier = var.test_context.workspace
}

locals {
  # The default of `var.display_name` in ../../meshstack_integration.tf. A deployment that renamed
  # its definition has to say so here.
  display_name = "meshStack Workspace Starterkit"

  definition = one([
    for definition in data.meshstack_building_block_definitions.published.building_block_definitions
    : definition if definition.spec.display_name == local.display_name
  ])

  version = var.test_context.bbd_draft ? try(local.definition.version_latest, null) : try(local.definition.version_latest_release, null)
}

output "version_ref" {
  value = { uuid = try(local.version.uuid, "") }

  precondition {
    condition     = local.definition != null
    error_message = "No building block definition named '${local.display_name}' in workspace '${var.test_context.workspace}'. Deploy it before smoke testing it."
  }

  precondition {
    condition     = local.version != null
    error_message = "Building block definition '${local.display_name}' has no ${var.test_context.bbd_draft ? "version" : "released version"}. Check that test_context.bbd_draft matches the `hub.bbd_draft` it was deployed with."
  }
}
