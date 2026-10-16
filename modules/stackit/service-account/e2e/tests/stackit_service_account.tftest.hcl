# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "stackit_service_account" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = startswith(try(jsondecode(meshstack_building_block.this.status.outputs["service_account_email"].value), ""), "${var.test_context.run_id}-sa")
    error_message = "Expected the email of the `${var.test_context.run_id}-sa` service account, got ${try(meshstack_building_block.this.status.outputs["service_account_email"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^https://portal\\.stackit\\.cloud/projects/[0-9a-f-]{36}/service-accounts$", try(jsondecode(meshstack_building_block.this.status.outputs["service_account_url"].value), "")))
    error_message = "Expected service_account_url to link the project's service accounts, got ${try(meshstack_building_block.this.status.outputs["service_account_url"].value, "no such output")}."
  }
}
