# The one case that really orders: a TTL is set, so the building block computes an expiry date and
# stamps it on everything it creates.
#
# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "meshstack_workspace_starterkit" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["workspace_identifier"].value), null) == output.expected_workspace_identifier
    error_message = "Reported workspace identifier is not the one that was ordered."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["payment_method_identifier"].value), null) == output.expected_payment_method_identifier
    error_message = "Payment method identifier is not derived from the workspace identifier."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["project_identifier"].value), null) == output.expected_project_identifier
    error_message = "Reported project identifier is not the one that was ordered."
  }

  # Whether the landing zone's own building block is final by now decides whether the tenant can be
  # deleted at all — see the destroy failures in the PR.
  assert {
    condition     = alltrue([for status in output.landing_zone_building_blocks : status == "SUCCEEDED"])
    error_message = "The landing zone's building blocks on the new tenant are not all SUCCEEDED: ${jsonencode(output.landing_zone_building_blocks)}."
  }

  # The date is the ordered TTL counted from the block's own creation time — nobody passed a date in.
  assert {
    condition     = contains(output.expected_expiry_dates, try(jsondecode(meshstack_building_block.this.status.outputs["workspace_expiry_date"].value), null))
    error_message = "Expiry date is not the ordered TTL counted from the run: got ${try(meshstack_building_block.this.status.outputs["workspace_expiry_date"].value, "no such output")}, expected one of ${jsonencode(output.expected_expiry_dates)}."
  }
}
