# try: a failed run reports no outputs, and indexing a missing one would bury the status assertion.

run "stackit_kubernetes" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^https://portal\\.stackit\\.cloud/projects/[0-9a-f-]{36}$", try(jsondecode(meshstack_building_block.this.status.outputs["ske_project_url"].value), "")))
    error_message = "Expected ske_project_url to deeplink the hosting STACKIT project, got ${try(meshstack_building_block.this.status.outputs["ske_project_url"].value, "no such output")}."
  }

  assert {
    condition     = strcontains(try(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), ""), "# STACKIT Kubernetes Platform: **${var.test_context.run_id}-")
    error_message = "Expected the summary to name the platform after the run id."
  }

  assert {
    condition     = strcontains(try(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), ""), "One step left: create the Harbor robot account")
    error_message = "Expected the summary of a phase 1 order to ask for the Harbor robot."
  }
}
