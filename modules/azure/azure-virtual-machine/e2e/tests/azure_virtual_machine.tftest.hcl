# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing, which buries the status assertion.

run "azure_virtual_machine" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "Building block run did not succeed: health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-rg/providers/Microsoft\\.Compute/virtualMachines/${var.test_context.run_id}$", try(jsondecode(meshstack_building_block.this.status.outputs["vm_id"].value), "")))
    error_message = "Expected a VM resource ID for ${var.test_context.run_id} in resource group ${var.test_context.run_id}-rg, got ${try(meshstack_building_block.this.status.outputs["vm_id"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^10\\.0\\.1\\.\\d{1,3}$", try(jsondecode(meshstack_building_block.this.status.outputs["vm_private_ip"].value), "")))
    error_message = "Expected a private IP in the default subnet 10.0.1.0/24, got ${try(meshstack_building_block.this.status.outputs["vm_private_ip"].value, "no such output")}."
  }

  assert {
    condition     = startswith(try(jsondecode(meshstack_building_block.this.status.outputs["azure_portal_url"].value), ""), "https://portal.azure.com/#@")
    error_message = "Expected azure_portal_url to deeplink the Azure Portal, got ${try(meshstack_building_block.this.status.outputs["azure_portal_url"].value, "no such output")}."
  }
}
