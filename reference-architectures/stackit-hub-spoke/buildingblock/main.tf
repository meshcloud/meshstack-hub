module "foundation" {
  source = "github.com/meshcloud/meshstack-hub//reference-architectures/stackit-sandbox-landingzone/buildingblock?ref=${var.hub.git_ref}"

  workspace                               = var.workspace
  use_global_location                     = var.use_global_location
  stackit_org                             = var.stackit_org
  stackit_owner_email                     = var.stackit_owner_email
  stackit_service_account_key             = var.stackit_service_account_key
  platform_identifier                     = var.platform_identifier
  tags                                    = var.tags
  role_mapping                            = var.role_mapping
  stackit_organization_onboarding_enabled = var.stackit_organization_onboarding_enabled
  network_area_tag_name                   = var.network_area_tag_name
  hub                                     = var.hub
}

module "network_area_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network-area?ref=${var.hub.git_ref}"

  stackit_organization_id = var.stackit_org
  stackit_project_id      = module.foundation.backplane_project_id

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "network_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network?ref=${var.hub.git_ref}"

  stackit_organization_id           = var.stackit_org
  stackit_project_id                = module.foundation.backplane_project_id
  stackit_network_min_prefix_length = var.tenant_network_min_prefix_length
  stackit_network_max_prefix_length = var.tenant_network_max_prefix_length

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "network_area_hub" {
  wait_for_completion = true
  depends_on          = [module.network_area_integration]

  spec = {
    building_block_definition_version_ref = {
      uuid = module.network_area_integration.building_block_definition.version_ref.uuid
    }
    display_name = "Hub Network Area"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    inputs = {
      network_area_name = {
        value = jsonencode(var.hub_network_area_name)
      }
      network_ranges = {
        value = jsonencode(jsonencode(var.hub_network_ranges))
      }
      transfer_network = {
        value = jsonencode(var.hub_transfer_network)
      }
      min_prefix_length = {
        value = jsonencode(var.hub_min_prefix_length)
      }
      max_prefix_length = {
        value = jsonencode(var.hub_max_prefix_length)
      }
      default_prefix_length = {
        value = jsonencode(var.hub_default_prefix_length)
      }
      default_nameservers = {
        value = jsonencode(jsonencode(var.hub_default_nameservers))
      }
    }
  }
}

# Looks up the default landing zone that `module.foundation` already registered (via the nested
# `modules/stackit` platform integration), without needing new outputs threaded through
# sandbox-landingzone. Used below only as an input into the independent `networked` landing zone —
# never fed back into `module.foundation` itself, which would create a dependency cycle.
data "meshstack_landingzone" "foundation_default" {
  metadata   = { name = "${var.platform_identifier}-default" }
  depends_on = [module.foundation]
}

resource "meshstack_landingzone" "networked" {
  metadata = {
    name               = "${var.platform_identifier}-networked"
    owned_by_workspace = var.workspace
    tags = merge(var.tags.landingzone, {
      (var.network_area_tag_name) = [jsondecode(meshstack_building_block.network_area_hub.status.outputs["network_area_id"].value)]
    })
  }

  spec = {
    display_name                  = "STACKIT Networked"
    description                   = "STACKIT landing zone whose projects are placed in the hub network area."
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref                  = data.meshstack_landingzone.foundation_default.spec.platform_ref
    platform_properties           = { custom = {} }
    mandatory_building_block_refs = data.meshstack_landingzone.foundation_default.spec.mandatory_building_block_refs
  }
}
