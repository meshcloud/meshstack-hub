locals {
  # Hub-and-spoke networking is deployed only when the operator supplies a `network` object.
  network_enabled = var.network != null

  # Only resolvable once the hub network area building block has completed.
  network_area_id = local.network_enabled ? jsondecode(meshstack_building_block.network_area_hub.status.outputs["network_area_id"].value) : null
}

# ── Sandbox landing zone foundation (always deployed) ──

resource "meshstack_location" "this" {
  lifecycle {
    enabled = !var.use_global_location
  }

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
    location_name               = var.use_global_location ? "global" : meshstack_location.this.metadata.name
    platform_identifier         = var.platform_identifier
    tags                        = var.tags
  }
}

# ── Self-service project starterkit (always deployed) ──

# Registered unconditionally, with no option to turn it off: its draft state follows var.hub.bbd_draft
# like every other definition here, so a deployment running the architecture in draft registers it
# without releasing it and nobody outside the owning workspace can order it. The select the application
# team sees is built from the landing zones that actually exist, so no configuration is needed to keep
# the two in step.
module "stackit_project_starterkit" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/stackit-project-starterkit?ref=${var.hub.git_ref}"

  platform_ref = module.stackit_integration.platform_ref
  landing_zone_refs = merge(
    { "sandbox" = module.stackit_integration.landingzone_refs["default"] },
    local.network_enabled ? { "hub&spoke" = module.stackit_integration.landingzone_refs["networked"] } : {}
  )

  # `sandbox` is always present, so this default holds whether or not networking is enabled. Naming it
  # rather than taking the first key matters: `keys()` sorts alphabetically, so the first key is
  # `hub&spoke` as soon as networking is on.
  default_landing_zone = "sandbox"

  # Only `hub&spoke` gets an entry, so that is the only landing zone where the starterkit creates a
  # spoke network. An empty map — networking disabled — means it never does, and the `network` input it
  # still shows is simply ignored.
  network_bbd_version_refs = local.network_enabled ? {
    "hub&spoke" = module.network_integration.building_block_definition.version_ref
  } : {}

  # The same bounds the `STACKIT Network` definition validates against, so the starterkit can render
  # the allowed range into its `network` default and reject a default the area would refuse. The
  # fallbacks only apply when networking is off, where no spoke network can be created anyway.
  network_prefix_length = {
    min = try(var.network.tenant_network_min_prefix_length, 24)
    max = try(var.network.tenant_network_max_prefix_length, 28)
  }

  project_tags  = var.tags.project
  owner_tag_key = var.tags.project_owner_tag_key

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# ── Hub-and-spoke network topology (optional — deployed only when var.network is set) ──

module "network_area_integration" {
  lifecycle {
    enabled = local.network_enabled
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network-area?ref=${var.hub.git_ref}"

  stackit_organization_id = var.stackit_org
  stackit_project_id      = stackit_resourcemanager_project.foundation.project_id

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "network_integration" {
  lifecycle {
    enabled = local.network_enabled
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network?ref=${var.hub.git_ref}"

  stackit_organization_id           = var.stackit_org
  stackit_project_id                = stackit_resourcemanager_project.foundation.project_id
  stackit_network_min_prefix_length = var.network.tenant_network_min_prefix_length
  stackit_network_max_prefix_length = var.network.tenant_network_max_prefix_length

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "network_area_hub" {
  lifecycle {
    enabled = local.network_enabled
  }

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
