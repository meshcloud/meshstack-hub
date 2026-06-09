run "building_block_manual_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "manual hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["text"].value_string == "Hello, Manual World!"
    error_message = "manual hub building block expected output text to be 'Hello, Manual World!', got ${meshstack_building_block_v2.this.status.outputs["text"].value_string}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["flag"].value_bool == true
    error_message = "manual hub building block expected output flag to be true, got ${meshstack_building_block_v2.this.status.outputs["flag"].value_bool}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["num"].value_int == 42
    error_message = "manual hub building block expected output num to be 42, got ${meshstack_building_block_v2.this.status.outputs["num"].value_int}"
  }

  # SINGLE_SELECT inputs are mirrored to a STRING output by the manual runner.
  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["single_select"].value_string == "option1"
    error_message = "manual hub building block expected output single_select to be 'option1', got ${meshstack_building_block_v2.this.status.outputs["single_select"].value_string}"
  }
}
