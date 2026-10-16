run "stackit_service_account_federation" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Federation building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = meshstack_building_block.this.status.outputs["service_account_email"].value == meshstack_building_block.service_account.status.outputs["service_account_email"].value
    error_message = "Expected the federation to pass on the email of the service account it federated, got ${meshstack_building_block.this.status.outputs["service_account_email"].value}."
  }

  assert {
    condition     = meshstack_building_block.probe.status.status == "SUCCEEDED"
    error_message = "Probe run did not succeed, so it could not act as the federated service account: ${meshstack_building_block.probe.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.probe.status.outputs["project_name"].value) != ""
    error_message = "Expected the probe to read its project's name, got ${meshstack_building_block.probe.status.outputs["project_name"].value}."
  }
}
