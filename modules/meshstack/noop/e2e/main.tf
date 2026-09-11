variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    run_id      = string
  })
  nullable = false
}

# A tag input reads its value from an existing meshStack tag, so the e2e test provisions its own
# tag definition and sets it on the test workspace to exercise the input end-to-end. It cannot be
# destroyed while the building block definition below reads it, so referencing its `spec.key` from
# the module's `tag_key` input (and the workspace tag depending on the definition) gets destroy
# order right on its own.
resource "meshstack_tag_definition" "noop_e2e" {
  spec = {
    target_kind  = "meshWorkspace"
    key          = "noop-e2e-tag-${var.test_context.run_id}"
    display_name = "NoOp E2E Tag"
    value_type   = { string = {} }
  }
}

resource "meshstack_workspace_tag" "noop_e2e" {
  metadata = {
    workspace_identifier = var.test_context.workspace
    key                  = meshstack_tag_definition.noop_e2e.spec.key
  }
  spec = {
    values = ["e2e-tag-value"]
  }
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
  tag_object = "WORKSPACE"
  tag_key    = meshstack_tag_definition.noop_e2e.spec.key
}

resource "meshstack_building_block" "this" {
  # ensures the tag has a value before the building block run reads it
  depends_on = [meshstack_workspace_tag.noop_e2e]

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
      # conditional_text is asked for because flag is true above; its condition is `input.flag == true`.
      conditional_text = { value = jsonencode("Shown because flag is true") }
      # hidden_conditional_text = <nothing>  -> Its condition (`input.flag == false`) never holds while flag is true,
      # so meshPanel hides it and it can be safely skipped here, exactly like optional_text.
      # A JSON-type input reaches Terraform as raw JSON text, exactly like a CODE input, so it must be jsonencode'd twice.
      deploy_settings   = { value = jsonencode(jsonencode({ greeting = "Hello from e2e", shout = true })) }
      sensitive_text    = { sensitive = { secret_value = "Hidden value" } }
      single_select     = { value = jsonencode("single1") }
      multi_select      = { value = jsonencode(["multi1", "multi2"]) }
      multi_select_json = { value = jsonencode(["multi2", "multi1"]) }
      # tag_value       = <nothing>  -> TAG-assigned inputs are read by meshStack from the workspace tag, not supplied here.
      # Settable here because the test key owns the definition; an app team could not fill this in.
      operator_text = { value = jsonencode("Set by the platform operator") }
    }
  }
}
