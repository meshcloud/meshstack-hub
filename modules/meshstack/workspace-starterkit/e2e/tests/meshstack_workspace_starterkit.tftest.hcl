# A TTL is ordered, so the building block computes an expiry date and stamps it on everything it
# creates.

run "meshstack_workspace_starterkit" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["workspace_identifier"].value) == output.expected_workspace_identifier
    error_message = "Reported workspace identifier is not the one that was ordered."
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["payment_method_identifier"].value) == output.expected_payment_method_identifier
    error_message = "Payment method identifier is not derived from the workspace identifier."
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["project_identifier"].value) == output.expected_project_identifier
    error_message = "Reported project identifier is not the one that was ordered."
  }

  # The date is the ordered TTL applied to the block's own creation time, which is what makes this
  # building block self-tracking: nobody passed a date in.
  assert {
    condition     = contains(output.expected_expiry_dates, jsondecode(meshstack_building_block.this.status.outputs["workspace_expiry_date"].value))
    error_message = "Expiry date is not the ordered TTL counted from the run: got ${meshstack_building_block.this.status.outputs["workspace_expiry_date"].value}, expected one of ${jsonencode(output.expected_expiry_dates)}."
  }
}
