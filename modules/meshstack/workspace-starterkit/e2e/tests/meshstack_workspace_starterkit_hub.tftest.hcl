run "meshstack_workspace_starterkit_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "workspace-starterkit hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["workspace_identifier"].value) == output.workspace_identifier
    error_message = "workspace-starterkit hub building block expected output workspace_identifier to be ${output.workspace_identifier}, got ${jsondecode(meshstack_building_block.this.status.outputs["workspace_identifier"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["payment_method_identifier"].value) == "${output.workspace_identifier}-payment-method"
    error_message = "workspace-starterkit hub building block expected output payment_method_identifier to be ${output.workspace_identifier}-payment-method, got ${jsondecode(meshstack_building_block.this.status.outputs["payment_method_identifier"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["project_identifier"].value) == output.project_identifier
    error_message = "workspace-starterkit hub building block expected output project_identifier to be ${output.project_identifier}, got ${jsondecode(meshstack_building_block.this.status.outputs["project_identifier"].value)}"
  }

  assert {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", jsondecode(meshstack_building_block.this.status.outputs["workspace_expiry_date"].value)))
    error_message = "workspace-starterkit hub building block expected output workspace_expiry_date to be a YYYY-MM-DD date, got ${jsondecode(meshstack_building_block.this.status.outputs["workspace_expiry_date"].value)}"
  }
}
