run "building_block_manual_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "manual hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["text"].value) == "Hello, Manual World!"
    error_message = "manual hub building block expected output text to be 'Hello, Manual World!', got ${jsondecode(meshstack_building_block.this.status.outputs["text"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["flag"].value) == true
    error_message = "manual hub building block expected output flag to be true, got ${jsondecode(meshstack_building_block.this.status.outputs["flag"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["num"].value) == 42
    error_message = "manual hub building block expected output num to be 42, got ${jsondecode(meshstack_building_block.this.status.outputs["num"].value)}"
  }

  # SINGLE_SELECT inputs are mirrored to a STRING output by the manual runner.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["single_select"].value) == "option1"
    error_message = "manual hub building block expected output single_select to be 'option1', got ${jsondecode(meshstack_building_block.this.status.outputs["single_select"].value)}"
  }
}
