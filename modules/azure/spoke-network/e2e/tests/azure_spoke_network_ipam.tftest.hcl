# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.
#
# In foundation mode the published definition decides the variant, not `ipam`, so this file and the
# plain one order the same kind of spoke there.

variables {
  ipam = true
}

run "azure_spoke_network_ipam" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+-vnet$", try(jsondecode(meshstack_building_block.this.status.outputs["vnet_id"].value), "")))
    error_message = "Expected a vnet resource ID, got ${try(meshstack_building_block.this.status.outputs["vnet_id"].value, "no such output")}."
  }

  assert {
    condition = (startswith(try(jsondecode(meshstack_building_block.this.status.outputs["vnet_portal_url"].value), ""), "https://portal.azure.com/#@")
    && endswith(try(jsondecode(meshstack_building_block.this.status.outputs["vnet_portal_url"].value), ""), "/resource${try(jsondecode(meshstack_building_block.this.status.outputs["vnet_id"].value), "missing")}/overview"))
    error_message = "Expected vnet_portal_url to deep-link the vnet in the Azure Portal, got ${try(meshstack_building_block.this.status.outputs["vnet_portal_url"].value, "no such output")}."
  }

  assert {
    condition     = can(regex(output.expected_address_space, try(jsondecode(meshstack_building_block.this.status.outputs["address_space"].value), "")))
    error_message = "Expected an address space matching ${output.expected_address_space}, got ${try(meshstack_building_block.this.status.outputs["address_space"].value, "no such output")}."
  }

  assert {
    condition     = !output.ipam || can(regex("^https://portal\\.azure\\.com/#@[^/]+/resource/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/networkManagers/[^/]+/ipamPools/[^/]+/resourceOverviewId$", try(jsondecode(meshstack_building_block.this.status.outputs["ipam_pool_portal_url"].value), "")))
    error_message = "Expected ipam_pool_portal_url to deep-link the pool in the Azure Portal, got ${try(meshstack_building_block.this.status.outputs["ipam_pool_portal_url"].value, "no such output")}."
  }
}
