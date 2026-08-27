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

resource "meshstack_building_block" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.noop.building_block_definition.version_ref

    display_name = "smoke-test-noop-hub-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      flag              = { value = jsonencode(true) }
      num               = { value = jsonencode(1) }
      text              = { value = jsonencode("Hello, World!") }
      sensitive_text    = { sensitive = { secret_value = "Hidden value" } }
      single_select     = { value = jsonencode("single1") }
      multi_select      = { value = jsonencode(["multi1", "multi2"]) }
      multi_select_json = { value = jsonencode(["multi2", "multi1"]) }
    }
  }
}
