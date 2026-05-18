# Minimal reproduction module for a known meshStack provider bug.
#
# Bug: When a MANUAL building block definition includes SINGLE_SELECT or STATIC
# input types, the provider returns an "unexpected new value" error on apply
# because the API automatically creates corresponding outputs that were not
# declared in the Terraform configuration:
#
#   produced an unexpected new value:
#     .version_spec.outputs: new element "single_select" has appeared.
#     .version_spec.outputs: new element "static_note" has appeared.
#
# This module intentionally omits outputs for those inputs to trigger the bug.
# See: modules/meshstack/manual/meshstack_integration.tf for the happy-path
# workaround (those input types are commented out there until fixed upstream).

variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
  })
  nullable = false
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.test_context.workspace
    tags               = {}
  }

  spec = {
    display_name = "repro-manual-select-${var.test_context.name_suffix}"
    description  = "Reproduces provider bug with SINGLE_SELECT and STATIC inputs in MANUAL building blocks."
    target_type  = "WORKSPACE_LEVEL"
    readme       = "Reproduction case for provider bug with SINGLE_SELECT and STATIC input types in manual BBD."
  }

  version_spec = {
    draft         = true
    deletion_mode = "PURGE"
    implementation = {
      manual = {}
    }
    inputs = {
      single_select = {
        assignment_type   = "USER_INPUT"
        display_name      = "Single Select"
        selectable_values = ["option1", "option2"]
        type              = "SINGLE_SELECT"
      }
      static_note = {
        assignment_type = "STATIC"
        display_name    = "Static Note"
        type            = "STRING"
        argument        = jsonencode("A static note value")
      }
    }
    # Outputs intentionally omitted for single_select and static_note to reproduce
    # the "unexpected new value" provider error — the API auto-creates outputs for
    # those input types, causing a plan/apply mismatch.
    outputs = {}
  }
}
