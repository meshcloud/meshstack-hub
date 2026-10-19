run "stackit_service_account_federation" {
  assert {
    condition     = meshstack_building_block.federation.status.status == "SUCCEEDED"
    error_message = "The federation building block ended in ${meshstack_building_block.federation.status.status}."
  }

  assert {
    condition     = meshstack_building_block.probe.status.status == "SUCCEEDED"
    error_message = "The probe ended in ${meshstack_building_block.probe.status.status}; its run logs in as the federated service account."
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.probe.status.outputs["project_name"].value)) > 0
    error_message = "The probe read an empty project name."
  }
}
