run "azure_budget_alert_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure/budget-alert hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["budget_amount"].value) == 1000
    error_message = "expected budget_amount to be 1000, got ${jsondecode(meshstack_building_block.this.status.outputs["budget_amount"].value)}"
  }

  # main.tf orders the block with both addresses in one comma-separated string. The summary lists
  # local.contact_emails_list one address per line, so finding both as their own bullets is what
  # proves split(",") + trimspace produced two clean recipients rather than one malformed address.
  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "- e2e-test@example.com\n")
    error_message = "expected summary to list e2e-test@example.com as its own alert recipient, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "- e2e-test-second@example.com")
    error_message = "expected summary to list e2e-test-second@example.com as its own alert recipient, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }
}
