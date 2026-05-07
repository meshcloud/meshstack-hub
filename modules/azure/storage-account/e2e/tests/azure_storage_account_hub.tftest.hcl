run "azure_storage_account_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "azure/storage-account hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition = can(regex(
      "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/",
      meshstack_building_block_v2.this.status.outputs["storage_account_id"].value_string
    ))
    error_message = "expected storage_account_id to be a valid Azure Storage Account resource ID, got ${meshstack_building_block_v2.this.status.outputs["storage_account_id"].value_string}"
  }

  assert {
    condition     = startswith(meshstack_building_block_v2.this.status.outputs["storage_account_name"].value_string, "st")
    error_message = "expected storage_account_name to start with 'st', got ${meshstack_building_block_v2.this.status.outputs["storage_account_name"].value_string}"
  }

  assert {
    condition     = startswith(meshstack_building_block_v2.this.status.outputs["storage_account_resource_group"].value_string, "rg-st")
    error_message = "expected storage_account_resource_group to start with 'rg-st', got ${meshstack_building_block_v2.this.status.outputs["storage_account_resource_group"].value_string}"
  }
}
