# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "azure_postgresql" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "Building block run did not succeed: health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["postgresql_server_name"].value), null) == var.test_context.run_id
    error_message = "Expected postgresql_server_name ${var.test_context.run_id}, got ${try(meshstack_building_block.this.status.outputs["postgresql_server_name"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["postgresql_fqdn"].value), null) == "${var.test_context.run_id}.postgres.database.azure.com"
    error_message = "Expected postgresql_fqdn ${var.test_context.run_id}.postgres.database.azure.com, got ${try(meshstack_building_block.this.status.outputs["postgresql_fqdn"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["postgresql_version"].value), null) == "17"
    error_message = "Expected postgresql_version 17, the default, got ${try(meshstack_building_block.this.status.outputs["postgresql_version"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^https://portal\\.azure\\.com/#@[^/]+/resource/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-psql/providers/Microsoft\\.DBforPostgreSQL/flexibleServers/${var.test_context.run_id}$", try(jsondecode(meshstack_building_block.this.status.outputs["postgresql_portal_url"].value), "")))
    error_message = "Expected postgresql_portal_url to deeplink the Flexible Server in resource group ${var.test_context.run_id}-psql, got ${try(meshstack_building_block.this.status.outputs["postgresql_portal_url"].value, "no such output")}."
  }
}
