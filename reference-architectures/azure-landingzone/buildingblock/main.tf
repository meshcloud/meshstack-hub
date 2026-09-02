locals {
  # The identifier is unique across the whole meshStack instance and lands in every landing zone
  # name, so a playground deployment suffixes it instead of occupying the plain name.
  platform_identifier = var.playground_mode ? "${var.platform_identifier}-${random_string.playground_suffix.result}" : var.platform_identifier

  # ── Foundation ──
  hub_enabled      = try(var.foundation.hub, null) != null
  policies_enabled = try(var.foundation.policies, false)
  foundation_rgs   = try(var.foundation.resource_groups, {})

  # Management group identifiers come from the hierarchy this architecture creates under the
  # bootstrap scope (azure_management_groups, pre-configured STATIC by the platform team).
  lz_management_group      = module.management_groups.landing_zones_name
  corp_management_group    = module.management_groups.corp_name
  online_management_group  = module.management_groups.online_name
  sandbox_management_group = module.management_groups.sandbox_name
  connectivity_scope       = module.management_groups.connectivity_scope

  # Full resource-path scope for the building block backplanes' RBAC role assignments — the
  # landing-zones management group, so one backplane per building block covers Corp, Online and
  # Sandbox beneath it.
  landing_zones_scope = module.management_groups.landing_zones_scope

  # The spoke-network backplane identity lives in a stable platform-owned subscription. Defaults to
  # the platform subscription when no dedicated backplane subscription is given.
  backplane_subscription_id = coalesce(var.azure_backplane_subscription_id, var.azure_platform_subscription_id)

  archetype_management_groups = {
    corp    = local.corp_management_group
    online  = local.online_management_group
    sandbox = local.sandbox_management_group
  }

  # Spoke networks peer into the hub this architecture provisions (when foundation.hub is set — it
  # lives in the connectivity subscription/scope), otherwise into an existing hub supplied via the
  # azure_hub_* variables.
  spoke_hub = {
    subscription_id     = local.hub_enabled ? var.azure_connectivity_subscription_id : var.azure_hub_subscription_id
    scope               = local.hub_enabled ? local.connectivity_scope : var.azure_hub_scope
    resource_group_name = local.hub_enabled ? var.foundation.hub.hub_resource_group_name : var.azure_hub_resource_group_name
    vnet_name           = local.hub_enabled ? var.foundation.hub.hub_vnet_name : var.azure_hub_vnet_name
  }
}

# ── Enterprise-Scale management group hierarchy (created under the bootstrap scope) ──
module "management_groups" {
  source = "./modules/management-groups"

  # Same parent + name_prefix the bootstrap used, so the names match and the import blocks below adopt
  # the already-created management groups instead of trying to create duplicates.
  name_prefix                = var.azure_management_groups.name_prefix
  parent_management_group_id = var.azure_management_groups.parent_management_group_id
  landing_zones_display_name = var.azure_management_groups.landing_zones_display_name
  corp_display_name          = var.azure_management_groups.corp_display_name
  online_display_name        = var.azure_management_groups.online_display_name
  sandbox_display_name       = var.azure_management_groups.sandbox_display_name
  connectivity_display_name  = var.azure_management_groups.connectivity_display_name
}

# Adopt the management groups the bootstrap step already created into this building block's state, so
# meshStack manages them going forward (and the meshplatform module finds them already existing). The
# import IDs match the names the bootstrap used (same parent + name_prefix). Import blocks must live
# in the root module, but can target resources inside module.management_groups.
import {
  to = module.management_groups.azurerm_management_group.landing_zones
  id = "/providers/Microsoft.Management/managementGroups/${var.azure_management_groups.name_prefix}landing-zones"
}
import {
  to = module.management_groups.azurerm_management_group.corp
  id = "/providers/Microsoft.Management/managementGroups/${var.azure_management_groups.name_prefix}corp"
}
import {
  to = module.management_groups.azurerm_management_group.online
  id = "/providers/Microsoft.Management/managementGroups/${var.azure_management_groups.name_prefix}online"
}
import {
  to = module.management_groups.azurerm_management_group.sandbox
  id = "/providers/Microsoft.Management/managementGroups/${var.azure_management_groups.name_prefix}sandbox"
}
import {
  to = module.management_groups.azurerm_management_group.connectivity
  id = "/providers/Microsoft.Management/managementGroups/${var.azure_management_groups.name_prefix}connectivity"
}

resource "random_string" "playground_suffix" {
  lifecycle {
    enabled = var.playground_mode
  }

  length  = 6
  special = false
  upper   = false
}

# Dedicated meshStack location for the platform, unless the global location is used.
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
    description  = "Azure location created by the Azure Landing Zone reference architecture."
  }
}

# ── Azure platform + Corp/Online/Sandbox landing zones ──
# Registers the Azure Subscription platform in meshStack and creates one landing zone per
# Enterprise-Scale archetype, each pointing at the management group this architecture created under
# the bootstrap scope (see module.management_groups / local.*_management_group).
module "azure_platform" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure?ref=${var.hub.git_ref}"

  azure_management_group              = local.lz_management_group
  azure_subscription_provisioning     = var.azure_subscription_provisioning
  azure_subscription_owner_object_ids = var.azure_subscription_owner_object_ids

  landing_zones = {
    corp = {
      management_group_id = local.corp_management_group
      display_name        = "Azure Corp"
      description         = "Corp-connected landing zone: subscriptions are placed in the Corp management group for internal, hub-connected workloads. Order the Azure Spoke Network building block inside a project for routed connectivity to the hub."
    }
    online = {
      management_group_id = local.online_management_group
      display_name        = "Azure Online"
      description         = "Internet-facing landing zone: subscriptions are placed in the Online management group for public-facing workloads without a mandatory hub connection."
    }
    sandbox = {
      management_group_id = local.sandbox_management_group
      display_name        = "Azure Sandbox"
      description         = "Experimentation landing zone: subscriptions are placed in the Sandbox management group with relaxed guardrails for trying things out."
    }
  }

  meshstack = {
    owning_workspace_identifier = var.workspace
    platform_name               = local.platform_identifier
    location_name               = var.use_global_location ? "global" : meshstack_location.this.metadata.name
    tags                        = var.tags.landingzone
  }

  hub = var.hub
}

# ── Building blocks rolled out for the platform ──
# Each integration creates its own backplane (a UAMI federated to the building block definition,
# with a deploy role scoped to the landing-zones management group) and registers the definition, so
# application teams can order these into subscriptions created through the landing zones.

module "budget_alert" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/budget-alert?ref=${var.hub.git_ref}"

  azure_tenant_id       = var.azure_tenant_id
  azure_subscription_id = var.azure_platform_subscription_id
  azure_scope           = local.landing_zones_scope
  azure_location        = var.azure_location

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = var.tags.building_block
  }
  hub = var.hub
}

module "storage_account" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/storage-account?ref=${var.hub.git_ref}"

  azure_tenant_id       = var.azure_tenant_id
  azure_subscription_id = var.azure_platform_subscription_id
  azure_scope           = local.landing_zones_scope
  azure_location        = var.azure_location

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = var.tags.building_block
  }
  hub = var.hub
}

module "spoke_network" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/spoke-network?ref=${var.hub.git_ref}"

  azure_tenant_id                 = var.azure_tenant_id
  azure_hub_subscription_id       = local.spoke_hub.subscription_id
  azure_scope                     = local.landing_zones_scope
  azure_hub_scope                 = local.spoke_hub.scope
  azure_location                  = var.azure_location
  azure_hub_resource_group_name   = local.spoke_hub.resource_group_name
  azure_hub_vnet_name             = local.spoke_hub.vnet_name
  azure_backplane_subscription_id = local.backplane_subscription_id

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = var.tags.building_block
  }
  hub = var.hub
}

# ── Optional foundation ──
# Provisioned only when var.foundation is set. Leaving it null keeps the architecture to the
# meshStack-side wiring (platform, landing zones and the three building blocks above).

# Extra platform-owned resource groups (e.g. management/connectivity groups) in the platform
# subscription.
resource "azurerm_resource_group" "foundation" {
  for_each = local.foundation_rgs

  name     = each.key
  location = each.value.location
}

# Enterprise-Scale policy assignments on the existing Corp/Online/Sandbox management groups.
module "es_policies" {
  for_each = local.policies_enabled ? local.archetype_management_groups : {}

  source = "./modules/es-policies"

  management_group_id     = "/providers/Microsoft.Management/managementGroups/${each.value}"
  policy_path             = "${path.module}/policies/${each.key}"
  location                = var.azure_location
  template_file_variables = { default_location = var.azure_location }
}

# Central hub network: registers the Azure Hub Network building block (the connectivity counterpart
# to spoke-network). Always registered — it cannot be gated with `enabled` because its backplane
# carries its own provider configuration. Whether a hub vnet is actually provisioned is controlled
# by ordering an instance below (meshstack_building_block.hub), gated by var.foundation.hub.
module "hub_network" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/hub-network?ref=${var.hub.git_ref}"

  azure_tenant_id                    = var.azure_tenant_id
  azure_connectivity_subscription_id = var.azure_connectivity_subscription_id
  azure_scope                        = local.connectivity_scope
  azure_location                     = var.azure_location

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = var.tags.building_block
  }
  hub = var.hub
}

resource "meshstack_building_block" "hub" {
  lifecycle {
    enabled = local.hub_enabled
  }

  wait_for_completion = true
  depends_on          = [module.hub_network]

  spec = {
    building_block_definition_version_ref = {
      uuid = module.hub_network.building_block_definition.version_ref.uuid
    }
    display_name = "Hub Network"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    inputs = {
      hub_resource_group_name = { value = jsonencode(try(var.foundation.hub.hub_resource_group_name, "hub-network")) }
      hub_vnet_name           = { value = jsonencode(try(var.foundation.hub.hub_vnet_name, "hub-vnet")) }
      address_space           = { value = jsonencode(try(var.foundation.hub.address_space, "10.0.0.0/22")) }
      create_gateway_subnet   = { value = jsonencode(try(var.foundation.hub.create_gateway_subnet, true)) }
      deploy_firewall         = { value = jsonencode(try(var.foundation.hub.deploy_firewall, false)) }
      firewall_sku_tier       = { value = jsonencode(try(var.foundation.hub.firewall_sku_tier, "Standard")) }
    }
  }
}
