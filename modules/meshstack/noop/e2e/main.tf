variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string
  })
  nullable = false
}

module "noop" {
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
    building_block_definition_version_ref = module.noop.building_block_definition.version_ref

    display_name = "smoke-test-noop-hub-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      flag              = { value_bool = true }
      num               = { value_int = 1 }
      text              = { value_string = "Hello, World!" }
      sensitive_text    = { value_string_sensitive = "Hidden value" }
      single_select     = { value_single_select = "single1" }
      multi_select      = { value_multi_select = ["multi1", "multi2"] }
      multi_select_json = { value_multi_select = ["multi2", "multi1"] }
    }
  }
}
