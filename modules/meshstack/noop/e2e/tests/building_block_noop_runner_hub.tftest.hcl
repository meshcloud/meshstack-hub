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

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["conditional_text"].value) == "Shown because flag is true"
    error_message = "noop runner building block expected output conditional_text to be 'Shown because flag is true', got ${jsondecode(meshstack_building_block.this.status.outputs["conditional_text"].value)}"
  }

  assert {
    # hidden_conditional_text is intentionally left out of the building block's inputs (see
    # e2e/runner/main.tf): its condition never holds while flag is true, so it can be skipped.
    condition     = jsondecode(meshstack_building_block.this.status.outputs["hidden_conditional_text"].value) == "tf-default-value"
    error_message = "noop runner building block expected output hidden_conditional_text to fall back to the Terraform variable default 'tf-default-value', got ${jsondecode(meshstack_building_block.this.status.outputs["hidden_conditional_text"].value)}"
  }

  assert {
    # deploy_settings is a CODE-type output, so it needs a double jsondecode() — see the equivalent
    # assert in building_block_noop_hub.tftest.hcl for why.
    condition = (
      jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["deploy_settings"].value)))
      ==
      jsonencode({ greeting = "Hello from e2e", shout = true })
    )
    error_message = "noop runner building block expected output deploy_settings to be {greeting = \"Hello from e2e\", shout = true}, got ${jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["deploy_settings"].value)))}"
  }
}
