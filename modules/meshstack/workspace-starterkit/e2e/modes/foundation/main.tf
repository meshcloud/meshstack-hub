# Orders against the definition this foundation has already published. Nothing is built here.
variable "test_context" {
  type = object({
    # Owns the published definition and receives the ordered building block.
    workspace = string

    # Must match the `hub.bbd_draft` the foundation deployed the definition with: a draft
    # definition has no released version to order against.
    bbd_draft = bool
  })
  nullable = false
}

# Unused here: the root pipes one uniform surface to both modes. Neither can change a definition
# that is already published — which is why the root never leaves the TTL blank in this mode.
variable "run_id" {
  type = any
}

variable "ttl_optional" {
  type = any
}

# The definition is looked up through the meshStack API rather than handed in from the deployment's
# terraform state, so a foundation smoke test needs no credential beyond a meshStack API key — that
# state also holds the backplane's own API key secret — and the test targets what a user of the
# foundation actually sees.
data "meshstack_building_block_definitions" "published" {
  workspace_identifier = var.test_context.workspace
}

locals {
  # Must match `spec.display_name` in ../../meshstack_integration.tf, whose default this is. A
  # deployment that renamed its definition through `var.display_name` has to say so here.
  display_name = "meshStack Workspace Starterkit"

  # `one` yields null when nothing matches, and fails outright on a duplicate display name.
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
