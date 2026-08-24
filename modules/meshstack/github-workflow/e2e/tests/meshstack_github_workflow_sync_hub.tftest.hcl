# Sync variant: the runner triggers the workflow and polls it to completion. Outputs are not
# captured in sync mode, so the building block definition declares none.
#
# This file and its async sibling are separate test files on purpose: `tofu test` gives each file
# its own state and tears it down before the next file starts, so the two building block
# definitions never exist at the same time and the two variants never commit to the fixture
# repository concurrently.

variables {
  github_async = false
}

run "meshstack_github_workflow_sync_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "github workflow hub building block (sync) expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = try(meshstack_building_block.this.status.outputs["run_url"], null) == null
    error_message = "github workflow hub building block (sync) declares no outputs, but reported a run_url"
  }
}
