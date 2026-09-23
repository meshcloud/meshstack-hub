# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "stackit_secrets_manager" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^[0-9a-f-]{36}$", try(jsondecode(meshstack_building_block.this.status.outputs["instance_id"].value), "")))
    error_message = "Expected a UUID as instance_id, got ${try(meshstack_building_block.this.status.outputs["instance_id"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["kv_mount"].value), null) == try(jsondecode(meshstack_building_block.this.status.outputs["instance_id"].value), "")
    error_message = "Expected kv_mount to equal instance_id."
  }

  assert {
    condition     = endswith(try(jsondecode(meshstack_building_block.this.status.outputs["instance_url"].value), ""), "/secrets-manager/instances/${try(jsondecode(meshstack_building_block.this.status.outputs["instance_id"].value), "")}/overview")
    error_message = "Expected instance_url to deeplink the instance, got ${try(meshstack_building_block.this.status.outputs["instance_url"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["api_url"].value), null) == "https://prod.sm.eu01.stackit.cloud"
    error_message = "Unexpected api_url: ${try(meshstack_building_block.this.status.outputs["api_url"].value, "no such output")}."
  }
}
