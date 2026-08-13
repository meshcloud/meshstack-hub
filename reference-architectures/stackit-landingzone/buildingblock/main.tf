locals {
  # Hub-and-spoke networking is deployed only when the operator supplies a `network` object.
  network_enabled = var.network != null

  # Only resolvable once the hub network area building block has completed.
  network_area_id = local.network_enabled ? jsondecode(meshstack_building_block.network_area_hub[0].status.outputs["network_area_id"].value) : null
}

# ── Sandbox landing zone foundation (always deployed) ──

resource "meshstack_location" "this" {
  count = var.use_global_location ? 0 : 1

  metadata = {
    name               = var.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = var.platform_identifier
    description  = "STACKIT sandbox location created by the STACKIT Landing Zone."
  }
}

resource "stackit_resourcemanager_folder" "this" {
  name                = var.platform_identifier
  owner_email         = var.stackit_owner_email
  parent_container_id = var.stackit_org
}

# Foundation project hosting the landing-zone core assets (the project-creation service account).
# Created directly under the organization (not the landing-zone folder).
resource "stackit_resourcemanager_project" "foundation" {
  name                = "${var.platform_identifier}-foundation"
  owner_email         = var.stackit_owner_email
  parent_container_id = var.stackit_org
}

# --- State address migration (no resource recreation) ---
# The sandbox landing zone called this project `backplane`. Unifying the sandbox and hub-and-spoke
# architectures renamed it to `foundation`, because it now holds more than the backplane service
# account. Without this move a deployed landing zone destroys the project, and with it the
# project-creation service account that every tenant project names as its owner.
# `name` carries no RequiresReplace, so the `-backplane` -> `-foundation` rename updates in place.
moved {
  from = stackit_resourcemanager_project.backplane
  to   = stackit_resourcemanager_project.foundation
}

module "stackit_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit?ref=${var.hub.git_ref}"

  stackit_organization_id                 = var.stackit_org
  stackit_parent_container_id             = stackit_resourcemanager_folder.this.container_id
  stackit_project_id                      = stackit_resourcemanager_project.foundation.project_id
  stackit_service_account_name            = substr(var.platform_identifier, 0, 20)
  role_mapping                            = var.role_mapping
  stackit_organization_onboarding_enabled = var.stackit_organization_onboarding_enabled

  # The networked project definition places its projects in the hub network area via a static
  # `networkArea` label, so no landing zone tag (and no tag definition) is involved.
  stackit_networked_projects_enabled = local.network_enabled
  stackit_network_area_id            = local.network_area_id

  hub = var.hub

  meshstack = {
    owning_workspace_identifier = var.workspace
    location_name               = var.use_global_location ? "global" : meshstack_location.this[0].metadata.name
    platform_identifier         = var.platform_identifier
    tags                        = var.tags
  }
}

# ── Hub-and-spoke network topology (optional — deployed only when var.network is set) ──

module "network_area_integration" {
  count  = local.network_enabled ? 1 : 0
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network-area?ref=${var.hub.git_ref}"

  stackit_organization_id = var.stackit_org
  stackit_project_id      = stackit_resourcemanager_project.foundation.project_id

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "network_integration" {
  count  = local.network_enabled ? 1 : 0
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network?ref=${var.hub.git_ref}"

  stackit_organization_id           = var.stackit_org
  stackit_project_id                = stackit_resourcemanager_project.foundation.project_id
  stackit_network_min_prefix_length = var.network.tenant_network_min_prefix_length
  stackit_network_max_prefix_length = var.network.tenant_network_max_prefix_length

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "network_area_hub" {
  count               = local.network_enabled ? 1 : 0
  wait_for_completion = true
  depends_on          = [module.network_area_integration]

  spec = {
    building_block_definition_version_ref = {
      uuid = module.network_area_integration[0].building_block_definition.version_ref.uuid
    }
    display_name = "Hub Network Area"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    inputs = {
      network_area_name = {
        value = jsonencode(var.network.hub_network_area_name)
      }
      network_ranges = {
        value = jsonencode(jsonencode(var.network.hub_network_ranges))
      }
      transfer_network = {
        value = jsonencode(var.network.hub_transfer_network)
      }
      min_prefix_length = {
        value = jsonencode(var.network.hub_min_prefix_length)
      }
      max_prefix_length = {
        value = jsonencode(var.network.hub_max_prefix_length)
      }
      default_prefix_length = {
        value = jsonencode(var.network.hub_default_prefix_length)
      }
      default_nameservers = {
        value = jsonencode(jsonencode(var.network.hub_default_nameservers))
      }
    }
  }
}
