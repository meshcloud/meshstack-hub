locals {
  # The provider reads a ref without a uuid as unknown, not as the shared runner.
  runner_ref = var.runner_ref.uuid == null ? null : var.runner_ref

  # The identifier is unique across the whole meshStack instance and lands in every landing zone
  # name, so a playground deployment suffixes it instead of occupying the plain name.
  platform_identifier = var.playground_mode ? "${var.platform_identifier}-${random_string.playground_suffix.result}" : var.platform_identifier

  # STACKIT caps a service account name at 20 characters and rejects one ending in a dash, so cutting
  # the identifier to length can produce an invalid name. Cut shorter instead, drop whatever dashes
  # the cut exposed, and end with a hash of the full identifier so two names sharing a prefix stay
  # apart.
  #
  # Only when it does not fit: a name that already fits passes through untouched, because changing it
  # replaces the service account every tenant project names as its owner.
  service_account_name = length(local.platform_identifier) <= 20 ? local.platform_identifier : format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 15), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  )

  # Selecting `hub&spoke` deploys hub&spoke networking. The `network` input is hidden (and so
  # unset) unless it is selected, so the topology — not the presence of a network object — gates it.
  network_enabled = contains(var.topology, "hub&spoke")

  # Only resolvable once the hub network area building block has completed.
  network_area_id = local.network_enabled ? jsondecode(meshstack_building_block.network_area_hub.status.outputs["network_area_id"].value) : null

  location_name = var.use_global_location ? "global" : meshstack_location.this.metadata.name

  # A playground gets a root folder too, so its leftovers are easy to find and remove.
  root_folder_name  = var.root_folder_name != null ? var.root_folder_name : var.playground_mode ? "playground-${local.platform_identifier}" : null
  root_container_id = local.root_folder_name == null ? var.stackit_org : stackit_resourcemanager_folder.root.container_id

  # The meshPanel Tags form sends each tag map as a list of {key, values} entries.
  tags = {
    landingzone    = { for e in var.tags.landingzone : e.key => e.values }
    building_block = { for e in var.tags.building_block : e.key => e.values }
  }
}

# Flipping the flag on an existing platform would suffix or rename everything and change what may be destroyed.
resource "terraform_data" "playground_mode" {
  input = var.playground_mode

  lifecycle {
    ignore_changes = [input]

    postcondition {
      condition     = self.output == var.playground_mode
      error_message = "playground_mode cannot change after the order."
    }
  }
}

# Pinned at the first run, so a later run without imports keeps the service account every tenant
# project names as its owner. Read `input`: `output` is unknown at the first plan and would replace it.
resource "terraform_data" "project_service_account_name" {
  input = local.imports.project_definition == null ? local.service_account_name : local.imports.project_definition.service_account_name

  lifecycle {
    ignore_changes = [input]
  }
}

resource "random_string" "playground_suffix" {
  lifecycle {
    enabled = var.playground_mode
  }

  length  = 6
  special = false
  upper   = false
}

resource "meshstack_location" "this" {
  lifecycle {
    enabled = !var.use_global_location
  }

  metadata = {
    name               = local.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = local.platform_identifier
    description  = "STACKIT sandbox location created by the STACKIT Landing Zone."
  }
}

resource "stackit_resourcemanager_folder" "root" {
  name                = local.root_folder_name
  owner_email         = var.stackit_owner_email
  parent_container_id = var.stackit_org

  lifecycle {
    enabled         = local.root_folder_name != null
    prevent_destroy = !var.playground_mode
  }
}

resource "stackit_resourcemanager_folder" "this" {
  name                = local.platform_identifier
  owner_email         = var.stackit_owner_email
  parent_container_id = local.root_container_id

  lifecycle {
    prevent_destroy = !var.playground_mode
  }
}

# Next to the landing-zone folder when there is a root folder, so that folder holds only tenants.
resource "stackit_resourcemanager_project" "foundation" {
  name                = "${local.platform_identifier}-foundation"
  owner_email         = var.stackit_owner_email
  parent_container_id = local.root_folder_name == null ? stackit_resourcemanager_folder.this.container_id : local.root_container_id

  lifecycle {
    prevent_destroy = !var.playground_mode
  }
}

# The sandbox landing zone called this project `backplane`. Unifying the sandbox and hub&spoke
# architectures renamed it to `foundation`, because it now holds more than the backplane service
# account. Without this move a deployed landing zone destroys the project, and with it the
# project-creation service account the platform runs as.
# `name` carries no RequiresReplace, so the `-backplane` -> `-foundation` rename updates in place.
moved {
  from = stackit_resourcemanager_project.backplane
  to   = stackit_resourcemanager_project.foundation
}

module "stackit_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit?ref=${var.hub.git_ref}"

  stackit_organization_id                 = var.stackit_org
  stackit_project_owner_email             = var.stackit_owner_email
  stackit_parent_container_id             = stackit_resourcemanager_folder.this.container_id
  stackit_project_id                      = stackit_resourcemanager_project.foundation.project_id
  stackit_service_account_name            = terraform_data.project_service_account_name.input
  role_mapping                            = { admin = var.role_mapping.admin, user = var.role_mapping.user, reader = var.role_mapping.reader }
  stackit_organization_onboarding_enabled = var.role_mapping.organization_onboarding

  # The same bounds as the `STACKIT Network` definition the projects order from. Null keeps the
  # integration's defaults.
  stackit_networked_projects_enabled     = local.network_enabled
  stackit_network_area_id                = local.network_area_id
  stackit_network_definition_version_ref = local.network_enabled ? module.network_integration.building_block_definition.version_ref : null
  stackit_network_min_prefix_length      = local.network_enabled ? var.network.tenant_network_min_prefix_length : null
  stackit_network_max_prefix_length      = local.network_enabled ? var.network.tenant_network_max_prefix_length : null

  hub = var.hub

  meshstack = {
    owning_workspace_identifier = var.workspace
    runner_ref                  = local.runner_ref
    location_name               = local.location_name
    platform_identifier         = local.platform_identifier
    tags                        = local.tags
  }
}

module "service_account_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/service-account?ref=${var.hub.git_ref}"

  stackit_organization_id = var.stackit_org
  stackit_project_id      = stackit_resourcemanager_project.foundation.project_id

  stackit_assignable_roles = ["reader", "editor", "iam.member-admin", "ske.admin", "git.admin", "container-registry.admin", "dns.admin"]

  stackit_federation_backplane_email = module.service_account_federation_integration.backplane_service_account_email

  meshstack = { owning_workspace_identifier = var.workspace, tags = local.tags.building_block, runner_ref = local.runner_ref }
  hub       = var.hub
}

module "service_account_federation_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/service-account-federation?ref=${var.hub.git_ref}"

  # Also deletes this definition before its parent's, which meshStack's `fk_tbb_Parent` constraint
  # requires.
  service_account_definition_ref = module.service_account_integration.building_block_definition.ref

  stackit_project_id = stackit_resourcemanager_project.foundation.project_id

  meshstack = { owning_workspace_identifier = var.workspace, tags = local.tags.building_block, runner_ref = local.runner_ref }
  hub       = var.hub
}

module "network_area_integration" {
  lifecycle {
    enabled = local.network_enabled
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network-area?ref=${var.hub.git_ref}"

  stackit_organization_id = var.stackit_org
  stackit_project_id      = stackit_resourcemanager_project.foundation.project_id

  meshstack = { owning_workspace_identifier = var.workspace, tags = local.tags.building_block, runner_ref = local.runner_ref }
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

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = local.tags.building_block
    runner_ref                  = local.runner_ref
    supported_platforms         = local.network_enabled ? [module.stackit_integration.landingzone_refs["spoke"]] : []
  }
  hub = var.hub
}

resource "meshstack_building_block" "network_area_hub" {
  lifecycle {
    enabled = local.network_enabled

    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  wait_for_completion = true

  # The block's delete run authenticates through the backplane's workload identity federation, which
  # the definition version alone doesn't order after this block — without this, destroy removes the
  # federation and its role assignment in parallel and the run fails with 401.
  depends_on = [module.network_area_integration]

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
