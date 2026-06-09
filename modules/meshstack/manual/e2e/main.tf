variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string
  })
  nullable = false
}

module "manual" {
  source = "../"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.manual.building_block_definition.version_ref

    display_name = "smoke-test-manual-hub-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      text          = { value_string = "Hello, Manual World!" }
      flag          = { value_bool = true }
      num           = { value_int = 42 }
      single_select = { value_single_select = "option1" }
      # static_note is STATIC — provided in the BBD, not by the user
    }
  }
}
