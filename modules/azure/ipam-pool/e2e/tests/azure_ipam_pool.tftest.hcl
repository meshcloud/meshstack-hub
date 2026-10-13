# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "azure_ipam_pool" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/networkManagers/${var.test_context.run_id}-avnm/ipamPools/${var.test_context.run_id}$", try(jsondecode(meshstack_building_block.this.status.outputs["ipam_pool_id"].value), "")))
    error_message = "Expected an IPAM pool resource ID under network manager ${var.test_context.run_id}-avnm, got ${try(meshstack_building_block.this.status.outputs["ipam_pool_id"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["address_prefix"].value), null) == "10.200.0.0/16"
    error_message = "Expected address_prefix 10.200.0.0/16, got ${try(meshstack_building_block.this.status.outputs["address_prefix"].value, "no such output")}."
  }
}
