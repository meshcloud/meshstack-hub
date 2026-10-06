locals {
  platform_service_account_email = jsondecode(meshstack_building_block.platform_service_account.status.outputs["service_account_email"].value)
  platform_service_account_id    = jsondecode(meshstack_building_block.platform_service_account.status.outputs["service_account_id"].value)
}

resource "meshstack_building_block" "platform_service_account" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = var.landingzone.service_account_bbd_version_ref
    display_name                          = "Automation Identity"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      service_account_name = { value = jsonencode(local.platform_service_account_name) }
      # `editor` covers every permission the blocks below need, including `ske.*`, `git.*`,
      # `container-registry.*`, `dns.*` and `service-enablement.service-state.edit`, so naming those
      # service roles as well adds nothing. `iam.member-admin` is the one addition: it carries
      # `iam.member.add` and `.remove`, which `editor` lacks and the registry block needs to grant
      # project members their registry role.
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
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_service_account.ref]
    building_block_definition_version_ref = var.landingzone.service_account_federation_bbd_version_ref
    display_name                          = "Bootstrap Identity Federation"
    target_ref                            = meshstack_tenant.stackit_project.ref

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
