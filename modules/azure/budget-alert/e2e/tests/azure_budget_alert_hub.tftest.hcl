run "azure_budget_alert_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "azure/budget-alert hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["budget_amount"].value_int == 1000
    error_message = "expected budget_amount to be 1000, got ${meshstack_building_block_v2.this.status.outputs["budget_amount"].value_int}"
  }
}
