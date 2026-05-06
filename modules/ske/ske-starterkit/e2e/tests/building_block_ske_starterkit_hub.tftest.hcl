run "building_block_ske_starterkit_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "ske-starterkit hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = can(regex("^https://", meshstack_building_block_v2.this.status.outputs["app_link_dev"].value_string))
    error_message = "ske-starterkit hub building block expected app_link_dev to be a URL, got ${meshstack_building_block_v2.this.status.outputs["app_link_dev"].value_string}"
  }

  assert {
    condition     = can(regex("^https://", meshstack_building_block_v2.this.status.outputs["app_link_prod"].value_string))
    error_message = "ske-starterkit hub building block expected app_link_prod to be a URL, got ${meshstack_building_block_v2.this.status.outputs["app_link_prod"].value_string}"
  }
}
