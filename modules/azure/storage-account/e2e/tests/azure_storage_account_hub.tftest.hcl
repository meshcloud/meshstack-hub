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

  # Conditional input: account_replication_type's condition (`input.account_tier == "Standard"`)
  # holds here, so meshStack asked for it and its value flows through.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["account_replication_type"].value) == "GRS"
    error_message = "expected account_replication_type to be 'GRS', got ${jsondecode(meshstack_building_block.this.status.outputs["account_replication_type"].value)}"
  }

  # Optional input: blob_soft_delete_retention_days is left out of the building block's inputs (see
  # e2e/main.tf), so this asserts the Terraform variable's own default (null, soft-delete disabled)
  # flows through.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["blob_soft_delete_retention_days"].value) == null
    error_message = "expected blob_soft_delete_retention_days to be null (soft-delete left disabled), got ${jsondecode(meshstack_building_block.this.status.outputs["blob_soft_delete_retention_days"].value)}"
  }

  # JSON-Schema-driven input: network_rules arrives as JSON text and is decoded into the resource's
  # native network_rules block.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["network_default_action"].value) == "Deny"
    error_message = "expected network_default_action to be 'Deny', got ${jsondecode(meshstack_building_block.this.status.outputs["network_default_action"].value)}"
  }

  # Tag-backed input: the shared test workspace carries a BusinessUnit tag set to "IT", so
  # business_unit resolves to that value and a matching tag is applied to the storage account.
  # tags is a CODE-type output, hence the double decode (same as author/static_code in meshstack/noop).
  assert {
    condition     = jsondecode(jsondecode(meshstack_building_block.this.status.outputs["tags"].value)) == { BusinessUnit = "IT" }
    error_message = "expected tags to contain the resolved BusinessUnit tag, got ${jsondecode(jsondecode(meshstack_building_block.this.status.outputs["tags"].value))}"
  }
}
