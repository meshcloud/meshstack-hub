run "stackit_service_account_federation" {
  assert {
    condition     = meshstack_building_block.federation.status.succeeded
    error_message = "The federation building block ended in health status ${meshstack_building_block.federation.status.health_status}, action ${meshstack_building_block.federation.status.action}."
  }

  assert {
    condition     = meshstack_building_block.probe.status.succeeded
    error_message = "The probe ended in health status ${meshstack_building_block.probe.status.health_status}, action ${meshstack_building_block.probe.status.action}; its run logs in as the federated service account."
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.probe.status.outputs["project_name"].value)) > 0
    error_message = "The probe read an empty project name."
  }
}
