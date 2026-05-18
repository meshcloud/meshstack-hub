# Reproduces a known 400 error when a building block instance is created
# with an input that is not declared on the Building Block Definition version.
#
# Expected provider error:
#   Error: Error creating building block
#   Could not create building block, unexpected error: http error 400,
#   response '{"message":"The following inputs are not known for the Building
#   Block Definition Version <uuid>: single_select(SINGLE_SELECT)",
#   "errorCode":"BadRequest",...}'

variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
  })
  nullable = false
}

# Minimal happy-path BBD — only defines a "text" input, no single_select.
resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.test_context.workspace
    tags               = {}
  }

  spec = {
    display_name = "repro-unknown-input-${var.test_context.name_suffix}"
    description  = "BBD for reproducing unknown input 400 error."
    target_type  = "WORKSPACE_LEVEL"
    readme       = "Reproduction case: creating a BB instance with an input not declared on the BBD."
  }

  version_spec = {
    draft         = true
    deletion_mode = "PURGE"
    implementation = {
      manual = {}
    }
    inputs = {
      text = {
        assignment_type = "USER_INPUT"
        display_name    = "Text"
        type            = "STRING"
      }
    }
    outputs = {
      text = {
        assignment_type = "NONE"
        display_name    = "Text"
        type            = "STRING"
      }
    }
  }
}

# Attempt to create a building block instance passing single_select, which is
# NOT declared on the BBD above. The API must reject this with a 400.
resource "meshstack_building_block_v2" "this" {
  spec = {
    building_block_definition_version_ref = meshstack_building_block_definition.this.version_latest

    display_name = "repro-unknown-input-${var.test_context.name_suffix}"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.test_context.workspace
    }

    inputs = {
      text          = { value_string = "hello" }
      single_select = { value_single_select = "option1" } # not declared on the BBD
    }
  }
}
