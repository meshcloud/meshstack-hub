run "azure_postgresql_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure/postgresql hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition = can(regex(
      "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.DBforPostgreSQL/flexibleServers/",
      jsondecode(meshstack_building_block.this.status.outputs["postgresql_server_id"].value)
    ))
    error_message = "expected postgresql_server_id to be a valid Azure PostgreSQL Flexible Server resource ID, got ${jsondecode(meshstack_building_block.this.status.outputs["postgresql_server_id"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["postgresql_server_name"].value), "pg-")
    error_message = "expected postgresql_server_name to start with 'pg-', got ${jsondecode(meshstack_building_block.this.status.outputs["postgresql_server_name"].value)}"
  }

  assert {
    condition     = endswith(jsondecode(meshstack_building_block.this.status.outputs["postgresql_fqdn"].value), ".postgres.database.azure.com")
    error_message = "expected postgresql_fqdn to end with '.postgres.database.azure.com', got ${jsondecode(meshstack_building_block.this.status.outputs["postgresql_fqdn"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["resource_group_name"].value), "rg-pg-")
    error_message = "expected resource_group_name to start with 'rg-pg-', got ${jsondecode(meshstack_building_block.this.status.outputs["resource_group_name"].value)}"
  }
}
