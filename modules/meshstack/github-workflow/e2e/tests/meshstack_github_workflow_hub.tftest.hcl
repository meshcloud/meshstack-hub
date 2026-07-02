run "meshstack_github_workflow_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "github workflow hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = !try(var.test_context.fixtures.github.async, false) || try(length(jsondecode(meshstack_building_block.this.status.outputs["run_url"].value)) > 0, false)
    error_message = "github workflow hub building block expected non-empty run_url output in async mode"
  }

  assert {
    condition     = !try(var.test_context.fixtures.github.async, false) || try(can(regex("^https?://", jsondecode(meshstack_building_block.this.status.outputs["run_url"].value))), false)
    error_message = "github workflow hub building block expected async run_url output to look like an URL"
  }
}
