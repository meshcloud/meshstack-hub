# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "azure_vmss" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "Building block run did not succeed: health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["vmss_name"].value), null) == var.test_context.run_id
    error_message = "Expected vmss_name ${var.test_context.run_id}, got ${try(meshstack_building_block.this.status.outputs["vmss_name"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-vmss/providers/Microsoft\\.Compute/virtualMachineScaleSets/${var.test_context.run_id}$", try(jsondecode(meshstack_building_block.this.status.outputs["vmss_id"].value), "")))
    error_message = "Expected a scale set resource ID in resource group ${var.test_context.run_id}-vmss, got ${try(meshstack_building_block.this.status.outputs["vmss_id"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^[0-9a-f-]{36}$", try(jsondecode(meshstack_building_block.this.status.outputs["vmss_identity_principal_id"].value), "")))
    error_message = "Expected the principal ID of the scale set's managed identity, got ${try(meshstack_building_block.this.status.outputs["vmss_identity_principal_id"].value, "no such output")}."
  }
}
