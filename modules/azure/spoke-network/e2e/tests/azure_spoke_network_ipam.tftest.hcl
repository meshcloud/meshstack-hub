# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

variables {
  ipam = true
}

run "azure_spoke_network_ipam" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-spoke/providers/Microsoft\\.Network/virtualNetworks/[^/]+-vnet$", try(jsondecode(meshstack_building_block.this.status.outputs["vnet_id"].value), "")))
    error_message = "Expected a vnet in resource group ${var.test_context.run_id}-spoke, got ${try(meshstack_building_block.this.status.outputs["vnet_id"].value, "no such output")}."
  }

  # The pool is 10.200.0.0/16, and the definition was ordered with a /24.
  assert {
    condition     = can(regex("^10\\.200\\.[0-9]{1,3}\\.0/24$", try(jsondecode(meshstack_building_block.this.status.outputs["address_space"].value), "")))
    error_message = "Expected a /24 allocated from the pool 10.200.0.0/16, got ${try(meshstack_building_block.this.status.outputs["address_space"].value, "no such output")}."
  }
}
