run "azure_service_principal_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure/service-principal hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition = can(regex(
      "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      jsondecode(meshstack_building_block.this.status.outputs["application_id"].value)
    ))
    error_message = "expected application_id to be the created Entra application's client ID (a GUID), got ${jsondecode(meshstack_building_block.this.status.outputs["application_id"].value)}"
  }

  assert {
    condition = can(regex(
      "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      jsondecode(meshstack_building_block.this.status.outputs["service_principal_object_id"].value)
    ))
    error_message = "expected service_principal_object_id to be the created service principal's object ID (a GUID), got ${jsondecode(meshstack_building_block.this.status.outputs["service_principal_object_id"].value)}"
  }

  assert {
    condition = can(regex(
      "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      jsondecode(meshstack_building_block.this.status.outputs["tenant_id"].value)
    ))
    error_message = "expected tenant_id to be the Entra tenant ID the service principal was created in, got ${jsondecode(meshstack_building_block.this.status.outputs["tenant_id"].value)}"
  }

  assert {
    condition = can(regex(
      "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      jsondecode(meshstack_building_block.this.status.outputs["subscription_id"].value)
    ))
    error_message = "expected subscription_id to be the subscription the role assignment was created on, got ${jsondecode(meshstack_building_block.this.status.outputs["subscription_id"].value)}"
  }

  # role_name is an echo of the azure_role input, so on its own it proves only that the input
  # arrived. role_assignment_id is the resource ID Azure handed back, so asserting its shape is what
  # proves the role assignment on the target subscription really happened.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["role_name"].value) == "Contributor"
    error_message = "expected role_name to be 'Contributor', got ${jsondecode(meshstack_building_block.this.status.outputs["role_name"].value)}"
  }

  assert {
    condition = can(regex(
      "^/subscriptions/[0-9a-f-]+/providers/Microsoft[.]Authorization/roleAssignments/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      jsondecode(meshstack_building_block.this.status.outputs["role_assignment_id"].value)
    ))
    error_message = "expected role_assignment_id to be an Azure role assignment resource ID on the target subscription, got ${jsondecode(meshstack_building_block.this.status.outputs["role_assignment_id"].value)}"
  }

  # create_client_secret defaults to true, so a client secret with an expiry date must exist.
  assert {
    condition = can(regex(
      "^[0-9]{4}-[0-9]{2}-[0-9]{2}T",
      jsondecode(meshstack_building_block.this.status.outputs["secret_expiration_date"].value)
    ))
    error_message = "expected secret_expiration_date to be an RFC3339 timestamp, got ${jsondecode(meshstack_building_block.this.status.outputs["secret_expiration_date"].value)}"
  }
}
