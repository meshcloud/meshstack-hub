run "azure_storage_account_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure/storage-account hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition = can(regex(
      "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/",
      jsondecode(meshstack_building_block.this.status.outputs["storage_account_id"].value)
    ))
    error_message = "expected storage_account_id to be a valid Azure Storage Account resource ID, got ${jsondecode(meshstack_building_block.this.status.outputs["storage_account_id"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["storage_account_name"].value), "st")
    error_message = "expected storage_account_name to start with 'st', got ${jsondecode(meshstack_building_block.this.status.outputs["storage_account_name"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["storage_account_resource_group"].value), "rg-st")
    error_message = "expected storage_account_resource_group to start with 'rg-st', got ${jsondecode(meshstack_building_block.this.status.outputs["storage_account_resource_group"].value)}"
  }
}
