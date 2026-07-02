module "backplane" {
  source = "../../backplane"

  meshstack_workspace_identifier = var.test_context.workspace
  meshstack_endpoint             = var.meshstack_endpoint
  gcp_project_id                 = var.gcp_project_id
  gcp_region                     = var.gcp_region
  gcp_resource_name_prefix       = "noop-runner-${var.test_context.name_suffix}"
  runner_display_name            = "smoke-test-noop-runner-${var.test_context.name_suffix}"
}

module "noop" {
  source = "../../"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
  runner_ref = module.backplane.runner_ref
  depends_on = [module.backplane] # Without the backplane there is no runner and no place to run the BB.
}

resource "meshstack_building_block" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.noop.building_block_definition.version_ref

    display_name = "smoke-test-noop-runner-${var.test_context.name_suffix}"
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

  depends_on = [module.noop] # Destroy the instance before the definition to avoid reference errors.
}
