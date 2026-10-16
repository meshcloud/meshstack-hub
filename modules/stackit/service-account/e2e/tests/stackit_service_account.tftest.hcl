run "stackit_service_account" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["service_account_email"].value), "${var.test_context.run_id}-sa")
    error_message = "Expected the email of the `${var.test_context.run_id}-sa` service account, got ${meshstack_building_block.this.status.outputs["service_account_email"].value}."
  }

  assert {
    condition     = can(regex("^https://portal\\.stackit\\.cloud/projects/[0-9a-f-]{36}/service-accounts$", jsondecode(meshstack_building_block.this.status.outputs["service_account_url"].value)))
    error_message = "Expected service_account_url to link the project's service accounts, got ${meshstack_building_block.this.status.outputs["service_account_url"].value}."
  }
}
