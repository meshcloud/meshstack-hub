variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    run_id      = string
  })
  nullable = false
}

module "noop" {
  source = "../"

  bbd_display_name = "${var.test_context.run_id} meshStack NoOp Building Block"

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

    display_name = "${var.test_context.run_id}-noop"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      flag = { value = jsonencode(true) }
      num  = { value = jsonencode(1) }
      text = { value = jsonencode("Hello, World!") }
      # optional_text     = <nothing>  -> We intentionally leave this empty to test we can use optional inputs and they take the variable default value.
      sensitive_text    = { sensitive = { secret_value = "Hidden value" } }
      single_select     = { value = jsonencode("single1") }
      multi_select      = { value = jsonencode(["multi1", "multi2"]) }
      multi_select_json = { value = jsonencode(["multi2", "multi1"]) }
      # Settable here because the test key owns the definition; an app team could not fill this in.
      operator_text = { value = jsonencode("Set by the platform operator") }
    }
  }
}
