# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "stackit_postgres" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "Building block run did not succeed: health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = can(regex("^[0-9a-f-]{36}$", try(jsondecode(meshstack_building_block.this.status.outputs["instance_id"].value), "")))
    error_message = "Expected a UUID as instance_id, got ${try(meshstack_building_block.this.status.outputs["instance_id"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("\\.postgresql\\.eu01\\.onstackit\\.cloud$", try(jsondecode(meshstack_building_block.this.status.outputs["host"].value), "")))
    error_message = "Expected a PostgreSQL Flex host name, got ${try(meshstack_building_block.this.status.outputs["host"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["port"].value), null) == 5432
    error_message = "Unexpected port: ${try(meshstack_building_block.this.status.outputs["port"].value, "no such output")}."
  }

  assert {
    condition     = length(setintersection(keys(meshstack_building_block.this.status.outputs), ["database", "username", "jdbc_url", "uri"])) == 0
    error_message = "The instance building block reports database outputs: ${join(", ", keys(meshstack_building_block.this.status.outputs))}."
  }

  assert {
    condition     = meshstack_building_block.database.status.succeeded
    error_message = "Database building block run did not succeed: health status ${meshstack_building_block.database.status.health_status}, action ${meshstack_building_block.database.status.action}"
  }

  assert {
    condition     = can(regex("^[a-z_][a-z0-9_]*$", try(jsondecode(meshstack_building_block.database.status.outputs["database"].value), "")))
    error_message = "Expected a database named after workspace and project, got ${try(meshstack_building_block.database.status.outputs["database"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.database.status.outputs["username"].value), null) == try(jsondecode(meshstack_building_block.database.status.outputs["database"].value), "")
    error_message = "Expected the database user to be named like its database, got ${try(meshstack_building_block.database.status.outputs["username"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.database.status.outputs["jdbc_url"].value), null) == "jdbc:postgresql://${try(jsondecode(meshstack_building_block.database.status.outputs["host"].value), "")}:5432/${try(jsondecode(meshstack_building_block.database.status.outputs["database"].value), "")}?sslmode=require"
    error_message = "Unexpected jdbc_url: ${try(meshstack_building_block.database.status.outputs["jdbc_url"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.database.status.outputs["instance_id"].value), null) == try(jsondecode(meshstack_building_block.this.status.outputs["instance_id"].value), "")
    error_message = "Expected the database on the instance of the first building block, got ${try(meshstack_building_block.database.status.outputs["instance_id"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.database.status.outputs["host"].value), null) == try(jsondecode(meshstack_building_block.this.status.outputs["host"].value), "")
    error_message = "Expected the host of the first building block, got ${try(meshstack_building_block.database.status.outputs["host"].value, "no such output")}."
  }
}
