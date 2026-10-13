# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

variables {
  ipam = false
}

run "azure_spoke_network" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-spoke/providers/Microsoft\\.Network/virtualNetworks/[^/]+-vnet$", try(jsondecode(meshstack_building_block.this.status.outputs["vnet_id"].value), "")))
    error_message = "Expected a vnet in resource group ${var.test_context.run_id}-spoke, got ${try(meshstack_building_block.this.status.outputs["vnet_id"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["address_space"].value), null) == "10.201.0.0/24"
    error_message = "Expected the typed address space 10.201.0.0/24, got ${try(meshstack_building_block.this.status.outputs["address_space"].value, "no such output")}."
  }
}
