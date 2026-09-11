# A tag input reads its value from an existing meshStack tag, so the e2e test provisions its own
# tag definition and sets it on the test workspace — see ../main.tf for why referencing its
# `spec.key` from the module's `tag_key` input gets destroy order right on its own.
resource "meshstack_tag_definition" "noop_e2e" {
  spec = {
    target_kind  = "meshWorkspace"
    key          = "noop-e2e-runner-tag-${var.test_context.run_id}"
    display_name = "NoOp E2E Runner Tag"
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

module "backplane" {
  source = "../../backplane"

  meshstack_workspace_identifier = var.test_context.workspace
  meshstack_endpoint             = var.test_context.meshstack_endpoint
  gcp_project_id                 = var.test_context.fixtures.gcp.project_id
  gcp_region                     = var.gcp_region
  gcp_resource_name_prefix       = "${var.test_context.run_id}-noop-runner"
  runner_display_name            = "${var.test_context.run_id}-noop-runner"
}

module "noop" {
  source = "../../"

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

  runner_ref = module.backplane.runner_ref
  depends_on = [module.backplane] # Without the backplane there is no runner and no place to run the BB.
}

resource "meshstack_building_block" "this" {
  # ensures the tag has a value before the building block run reads it
  depends_on = [module.noop, meshstack_workspace_tag.noop_e2e] # Destroy the instance before the definition to avoid reference errors.

  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.noop.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-noop-runner"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      flag = { value = jsonencode(true) }
      num  = { value = jsonencode(1) }
      text = { value = jsonencode("Hello, World!") }
      # conditional_text is asked for because flag is true above; its condition is `input.flag == true`.
      conditional_text = { value = jsonencode("Shown because flag is true") }
      # hidden_conditional_text = <nothing>  -> Its condition (`input.flag == false`) never holds while flag is true,
      # so meshPanel hides it and it can be safely skipped here, exactly like optional_text.
      # The meshStack API requires a JSON-type input's value to be sent as JSON text (a string),
      # regardless of what type the Terraform variable declares it decodes into, so it must be
      # jsonencode'd twice.
      deploy_settings   = { value = jsonencode(jsonencode({ greeting = "Hello from e2e", shout = true })) }
      sensitive_text    = { sensitive = { secret_value = "Hidden value" } }
      single_select     = { value = jsonencode("single1") }
      multi_select      = { value = jsonencode(["multi1", "multi2"]) }
      multi_select_json = { value = jsonencode(["multi2", "multi1"]) }
      # Settable here because the test key owns the definition; an app team could not fill this in.
      operator_text = { value = jsonencode("Set by the platform operator") }
    }
  }
}
