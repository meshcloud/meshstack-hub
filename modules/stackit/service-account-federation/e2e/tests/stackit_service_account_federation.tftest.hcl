# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "stackit_service_account_federation" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Federation building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = try(meshstack_building_block.this.status.outputs["service_account_email"].value, null) == try(meshstack_building_block.service_account.status.outputs["service_account_email"].value, "")
    error_message = "Expected the federation to pass on the email of the service account it federated, got ${try(meshstack_building_block.this.status.outputs["service_account_email"].value, "no such output")}."
  }

  assert {
    condition     = meshstack_building_block.probe.status.status == "SUCCEEDED"
    error_message = "Probe run did not succeed, so it could not act as the federated service account: ${meshstack_building_block.probe.status.status}"
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.probe.status.outputs["project_name"].value), "") != ""
    error_message = "Expected the probe to read its project's name, got ${try(meshstack_building_block.probe.status.outputs["project_name"].value, "no such output")}."
  }
}
