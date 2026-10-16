locals {
  platform_service_account_email = jsondecode(meshstack_building_block.platform_service_account.status.outputs["service_account_email"].value)
  platform_service_account_id    = jsondecode(meshstack_building_block.platform_service_account.status.outputs["service_account_id"].value)
}

resource "meshstack_building_block" "platform_service_account" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} ended in ${self.status.status}. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = var.landingzone.service_account_bbd_version_ref
    display_name                          = "Automation Identity"
    target_ref                            = module.tenant.tenant.ref

    inputs = {
      service_account_name = { value = jsonencode(local.platform_service_account_name) }
      # `editor` covers the service roles of every block below. `iam.member-admin` adds
      # `iam.member.add` and `.remove`, with which the registry block grants members their role.
      roles = { value = jsonencode(jsonencode([
        "editor",
        "iam.member-admin",
      ])) }
    }
  }
}

# Trusts only the nested definition. The nested run registers all other definitions, so it
# federates them itself.
resource "meshstack_building_block" "bootstrap_federation" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} ended in ${self.status.status}. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_service_account.ref]
    building_block_definition_version_ref = var.landingzone.service_account_federation_bbd_version_ref
    display_name                          = "Bootstrap Identity Federation"
    target_ref                            = module.tenant.tenant.ref

    inputs = {
      service_account_email = { value = jsonencode(local.platform_service_account_email) }
      federated_building_block_definitions = {
        value = jsonencode(jsonencode([
          module.platform_integration.building_block_definition.uuid,
        ]))
      }
    }
  }
}
