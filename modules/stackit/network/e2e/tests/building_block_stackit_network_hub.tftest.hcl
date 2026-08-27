run "building_block_stackit_network_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "stackit network hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.this.status.outputs["network_id"].value)) > 0
    error_message = "stackit network hub building block expected non-empty network_id"
  }

  # The network area allocates the CIDR, so only the prefix length is predictable.
  assert {
    condition     = endswith(jsondecode(meshstack_building_block.this.status.outputs["network_cidr"].value), "/28")
    error_message = "stackit network hub building block expected a /28 network_cidr, got ${jsondecode(meshstack_building_block.this.status.outputs["network_cidr"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["network_url"].value), jsondecode(meshstack_building_block.this.status.outputs["network_id"].value))
    error_message = "stackit network hub building block expected network_url to contain the network id, got ${jsondecode(meshstack_building_block.this.status.outputs["network_url"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["network_url"].value), "portal.stackit.cloud")
    error_message = "stackit network hub building block expected network_url to point at the STACKIT portal, got ${jsondecode(meshstack_building_block.this.status.outputs["network_url"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "smoke-test-net-${var.test_context.name_suffix}")
    error_message = "stackit network hub building block expected the summary to name the network, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }
}
