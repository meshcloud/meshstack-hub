run "building_block_meshstack_api_key_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "meshstack api-key hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = trimspace(jsondecode(meshstack_building_block.this.status.outputs["client_id"].value)) != ""
    error_message = "meshstack api-key hub building block expected a non-empty client_id output"
  }

  assert {
    condition     = trimspace(jsondecode(meshstack_building_block.this.status.outputs["uuid"].value)) != ""
    error_message = "meshstack api-key hub building block expected a non-empty uuid output"
  }
}
