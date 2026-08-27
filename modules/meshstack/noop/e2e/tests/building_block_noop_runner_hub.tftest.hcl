run "building_block_noop_runner_hub" {
  module {
    source = "./runner"
  }

  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "noop runner building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["num"].value) == 1
    error_message = "noop runner building block expected output num to be 1, got ${jsondecode(meshstack_building_block.this.status.outputs["num"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["text"].value), "Hello, World! aws-cli/2")
    error_message = "noop runner building block expected output text to start with 'Hello, World! aws-cli/2', got ${jsondecode(meshstack_building_block.this.status.outputs["text"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["flag"].value) == true
    error_message = "noop runner building block expected output flag to be true, got ${jsondecode(meshstack_building_block.this.status.outputs["flag"].value)}"
  }
}
