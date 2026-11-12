run "stackit_service_account" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "The building block ended in health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}."
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["service_account_email"].value), "${var.test_context.run_id}-sa")
    error_message = "Expected the email of the `${var.test_context.run_id}-sa` service account, got ${meshstack_building_block.this.status.outputs["service_account_email"].value}."
  }

  assert {
    condition     = can(regex("^https://portal\\.stackit\\.cloud/service-accounts/[^/]+/overview\\?project=[0-9a-f-]{36}$", jsondecode(meshstack_building_block.this.status.outputs["service_account_url"].value)))
    error_message = "Expected service_account_url to open the service account in the STACKIT portal, got ${meshstack_building_block.this.status.outputs["service_account_url"].value}."
  }
}
