# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.
#
# In foundation mode the published definition decides the variant, not `ipam`, so this file and the
# `_ipam` one order the same kind of spoke there.

variables {
  ipam = false
}

run "azure_spoke_network" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+-vnet$", try(jsondecode(meshstack_building_block.this.status.outputs["vnet_id"].value), "")))
    error_message = "Expected a vnet resource ID, got ${try(meshstack_building_block.this.status.outputs["vnet_id"].value, "no such output")}."
  }

  assert {
    condition     = can(regex(output.expected_address_space, try(jsondecode(meshstack_building_block.this.status.outputs["address_space"].value), "")))
    error_message = "Expected an address space matching ${output.expected_address_space}, got ${try(meshstack_building_block.this.status.outputs["address_space"].value, "no such output")}."
  }
}
