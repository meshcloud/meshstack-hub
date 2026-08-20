run "building_block_stackit_network_area_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "stackit network-area hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["network_area_name"].value) == "smoke-test-na-${var.test_context.name_suffix}"
    error_message = "stackit network-area hub building block expected network_area_name to be 'smoke-test-na-${var.test_context.name_suffix}', got ${jsondecode(meshstack_building_block.this.status.outputs["network_area_name"].value)}"
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.this.status.outputs["network_area_id"].value)) > 0
    error_message = "stackit network-area hub building block expected non-empty network_area_id"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["transfer_network"].value) == "10.235.0.0/24"
    error_message = "stackit network-area hub building block expected transfer_network to be '10.235.0.0/24', got ${jsondecode(meshstack_building_block.this.status.outputs["transfer_network"].value)}"
  }

  # network_ranges is a CODE output, so its value decodes twice.
  assert {
    condition     = jsondecode(jsondecode(meshstack_building_block.this.status.outputs["network_ranges"].value)) == tolist(["10.234.0.0/16"])
    error_message = "stackit network-area hub building block expected network_ranges to be ['10.234.0.0/16'], got ${meshstack_building_block.this.status.outputs["network_ranges"].value}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["network_area_url"].value), jsondecode(meshstack_building_block.this.status.outputs["network_area_id"].value))
    error_message = "stackit network-area hub building block expected network_area_url to contain the network area id, got ${jsondecode(meshstack_building_block.this.status.outputs["network_area_url"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["network_area_url"].value), "portal.stackit.cloud")
    error_message = "stackit network-area hub building block expected network_area_url to point at the STACKIT portal, got ${jsondecode(meshstack_building_block.this.status.outputs["network_area_url"].value)}"
  }
}
