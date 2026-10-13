# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "azure_key_vault" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-kv/providers/Microsoft\\.KeyVault/vaults/${var.test_context.run_id}-[a-z0-9]{5}$", try(jsondecode(meshstack_building_block.this.status.outputs["key_vault_id"].value), "")))
    error_message = "Expected a Key Vault resource ID in resource group ${var.test_context.run_id}-kv, got ${try(meshstack_building_block.this.status.outputs["key_vault_id"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["key_vault_uri"].value), null) == "https://${try(jsondecode(meshstack_building_block.this.status.outputs["key_vault_name"].value), "")}.vault.azure.net/"
    error_message = "Expected key_vault_uri to address the vault by its name, got ${try(meshstack_building_block.this.status.outputs["key_vault_uri"].value, "no such output")}."
  }

  assert {
    condition     = startswith(try(jsondecode(meshstack_building_block.this.status.outputs["key_vault_portal_url"].value), ""), "https://portal.azure.com/#@")
    error_message = "Expected key_vault_portal_url to deeplink the Azure Portal, got ${try(meshstack_building_block.this.status.outputs["key_vault_portal_url"].value, "no such output")}."
  }
}
