run "building_block_meshstack_link_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "meshstack link hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^https?://", jsondecode(meshstack_building_block.this.status.outputs["url"].value)))
    error_message = "meshstack link hub building block expected url output to look like an URL, got ${jsondecode(meshstack_building_block.this.status.outputs["url"].value)}"
  }

  assert {
    condition     = output.expected_url == null || jsondecode(meshstack_building_block.this.status.outputs["url"].value) == output.expected_url
    error_message = "meshstack link hub building block expected url output '${output.expected_url}', got ${jsondecode(meshstack_building_block.this.status.outputs["url"].value)}"
  }

  assert {
    condition     = trimspace(jsondecode(meshstack_building_block.this.status.outputs["summary"].value)) != ""
    error_message = "meshstack link hub building block expected a non-empty summary output"
  }

  # Verifies the markdown round-trips intact — tables, pipes and backticks included.
  assert {
    condition     = output.expected_summary == null || jsondecode(meshstack_building_block.this.status.outputs["summary"].value) == output.expected_summary
    error_message = "meshstack link hub building block expected summary output to match the configured markdown, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }
}
