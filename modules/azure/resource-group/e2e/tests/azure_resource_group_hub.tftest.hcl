run "azure_resource_group_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "azure/resource-group hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = startswith(meshstack_building_block_v2.this.status.outputs["resource_group_name"].value_string, "rg-")
    error_message = "expected resource_group_name to start with 'rg-', got ${meshstack_building_block_v2.this.status.outputs["resource_group_name"].value_string}"
  }

  assert {
    condition = can(regex(
      "^/subscriptions/[^/]+/resourceGroups/rg-",
      meshstack_building_block_v2.this.status.outputs["resource_group_id"].value_string
    ))
    error_message = "expected resource_group_id to be a valid Azure Resource Group resource ID starting with /subscriptions/.../resourceGroups/rg-, got ${meshstack_building_block_v2.this.status.outputs["resource_group_id"].value_string}"
  }
}
