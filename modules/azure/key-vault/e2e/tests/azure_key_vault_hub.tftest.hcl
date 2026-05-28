run "azure_key_vault_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "azure/key-vault hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = startswith(meshstack_building_block_v2.this.status.outputs["key_vault_uri"].value_string, "https://")
    error_message = "expected key_vault_uri to start with 'https://', got ${meshstack_building_block_v2.this.status.outputs["key_vault_uri"].value_string}"
  }
}
