run "stackit_spoke_network_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "stackit spoke-network hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = length(meshstack_building_block_v2.this.status.outputs["network_id"].value_string) > 0
    error_message = "stackit spoke-network hub building block expected non-empty network_id"
  }

  assert {
    condition     = strcontains(meshstack_building_block_v2.this.status.outputs["network_cidr"].value_string, "/28")
    error_message = "stackit spoke-network hub building block expected network_cidr to contain /28, got ${meshstack_building_block_v2.this.status.outputs["network_cidr"].value_string}"
  }
}
