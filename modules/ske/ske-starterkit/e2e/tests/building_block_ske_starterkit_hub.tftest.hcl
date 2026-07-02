run "building_block_ske_starterkit_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "ske-starterkit hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^https://", jsondecode(meshstack_building_block.this.status.outputs["app_link_dev"].value)))
    error_message = "ske-starterkit hub building block expected app_link_dev to be a URL, got ${jsondecode(meshstack_building_block.this.status.outputs["app_link_dev"].value)}"
  }

  assert {
    condition     = can(regex("^https://", jsondecode(meshstack_building_block.this.status.outputs["app_link_prod"].value)))
    error_message = "ske-starterkit hub building block expected app_link_prod to be a URL, got ${jsondecode(meshstack_building_block.this.status.outputs["app_link_prod"].value)}"
  }
}
