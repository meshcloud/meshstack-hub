# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "azure_container_registry" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "Building block run did not succeed: health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = can(regex("^${var.test_context.run_id}[a-z0-9]{4}$", try(jsondecode(meshstack_building_block.this.status.outputs["acr_name"].value), "")))
    error_message = "Expected acr_name to be the run id plus a 4-character suffix, got ${try(meshstack_building_block.this.status.outputs["acr_name"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["acr_login_server"].value), null) == "${try(jsondecode(meshstack_building_block.this.status.outputs["acr_name"].value), "")}.azurecr.io"
    error_message = "Expected acr_login_server to be <acr_name>.azurecr.io, got ${try(meshstack_building_block.this.status.outputs["acr_login_server"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-acr/providers/Microsoft\\.ContainerRegistry/registries/${var.test_context.run_id}[a-z0-9]{4}$", try(jsondecode(meshstack_building_block.this.status.outputs["acr_id"].value), "")))
    error_message = "Expected a registry resource ID in resource group ${var.test_context.run_id}-acr, got ${try(meshstack_building_block.this.status.outputs["acr_id"].value, "no such output")}."
  }
}
