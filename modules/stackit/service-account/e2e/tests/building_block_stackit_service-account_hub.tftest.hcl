run "building_block_stackit_service_account_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "stackit service-account hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.this.status.outputs["service_account_email"].value)) > 0
    error_message = "stackit service-account hub building block expected non-empty service_account_email"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["service_account_url"].value), "portal.stackit.cloud")
    error_message = "stackit service-account hub building block expected service_account_url to point at the STACKIT portal, got ${jsondecode(meshstack_building_block.this.status.outputs["service_account_url"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["service_account_url"].value), "/service-accounts")
    error_message = "stackit service-account hub building block expected service_account_url to link to the service accounts overview, got ${jsondecode(meshstack_building_block.this.status.outputs["service_account_url"].value)}"
  }
}
