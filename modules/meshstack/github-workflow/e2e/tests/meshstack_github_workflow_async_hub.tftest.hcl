# Async variant: the runner triggers the workflow and hands it a run token, and the workflow calls
# back with step status and outputs. See the sync sibling for why these are two files.

variables {
  github_async = true
}

run "meshstack_github_workflow_async_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "github workflow hub building block (async) expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.this.status.outputs["run_url"].value)) > 0
    error_message = "github workflow hub building block (async) expected a non-empty run_url output"
  }

  assert {
    condition     = can(regex("^https?://", jsondecode(meshstack_building_block.this.status.outputs["run_url"].value)))
    error_message = "github workflow hub building block (async) expected the run_url output to look like an URL"
  }
}
