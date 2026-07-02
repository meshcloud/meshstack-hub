run "azure_resource_group_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure/resource-group hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["resource_group_name"].value), "rg-")
    error_message = "expected resource_group_name to start with 'rg-', got ${jsondecode(meshstack_building_block.this.status.outputs["resource_group_name"].value)}"
  }

  assert {
    condition = can(regex(
      "^/subscriptions/[^/]+/resourceGroups/rg-",
      jsondecode(meshstack_building_block.this.status.outputs["resource_group_id"].value)
    ))
    error_message = "expected resource_group_id to be a valid Azure Resource Group resource ID starting with /subscriptions/.../resourceGroups/rg-, got ${jsondecode(meshstack_building_block.this.status.outputs["resource_group_id"].value)}"
  }
}
