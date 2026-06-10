run "building_block_noop_runner_hub" {
  module {
    source = "./runner"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "noop runner building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["num"].value_int == 1
    error_message = "noop runner building block expected output num to be 1, got ${meshstack_building_block_v2.this.status.outputs["num"].value_int}"
  }

  assert {
    condition     = startswith(meshstack_building_block_v2.this.status.outputs["text"].value_string, "Hello, World! aws-cli/2")
    error_message = "noop runner building block expected output text to start with 'Hello, World! aws-cli/2', got ${meshstack_building_block_v2.this.status.outputs["text"].value_string}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["flag"].value_bool == true
    error_message = "noop runner building block expected output flag to be true, got ${meshstack_building_block_v2.this.status.outputs["flag"].value_bool}"
  }
}
