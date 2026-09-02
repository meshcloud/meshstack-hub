locals {
  # The identifier is unique across the whole meshStack instance and lands in every landing zone
  # name, so a playground deployment suffixes it instead of occupying the plain name.
  platform_identifier = var.playground_mode ? "${var.platform_identifier}-${random_string.playground_suffix.result}" : var.platform_identifier

  # meshStack caps a name at 45 characters, and a landing zone name is "<platform_name>-<archetype>"
  # (longest archetype "sandbox" adds 8), so the name feeding the platform, its landing zones and the
  # location has to fit in 37. Cut the identifier short of that, drop whatever dashes the cut exposed,
  # and end with a hash of the full identifier so two names sharing a prefix stay apart. A name that
  # already fits passes through untouched, so existing platforms keep their plain names.
  platform_name = length(local.platform_identifier) <= 37 ? local.platform_identifier : format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 32), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  )

  # The person who ordered this architecture, written to the landing zones' owner tag when the
  # platform team named one (var.tags.owner_tag_key). Empty key => no owner tag.
  owner_tags = var.tags.owner_tag_key == "" ? {} : { (var.tags.owner_tag_key) = [var.creator.displayName] }

  # The tags form hands landingzone/building_block back as lists of {key, values} entries (friendlier
  # than a dynamic-key map); turn each into the map(list(string)) the nested integrations take.
  tags = {
    landingzone    = { for e in var.tags.landingzone : e.key => e.values }
    building_block = { for e in var.tags.building_block : e.key => e.values }
  }

  # ── Foundation ──
  hub_enabled      = var.provision_hub
  policies_enabled = var.assign_policies
  foundation_rgs   = { for rg in var.foundation_resource_groups : rg.name => { location = rg.location } }

  # The two conditional provisioning inputs reassembled into the single object modules/azure expects
  # (exactly one of pre_provisioned / customer_agreement). meshStack shows only the selected one.
  azure_subscription_provisioning = var.subscription_provisioning_model == "customer_agreement" ? {
    customer_agreement = var.customer_agreement
    } : {
    pre_provisioned = var.pre_provisioned
  }

  # Management group identifiers come from the hierarchy this architecture creates under the
  # user-provided parent management group (var.azure_management_groups).
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

  # Spoke networks peer into the hub in the connectivity subscription/scope (the Connectivity MG is
  # always created). The hub vnet/RG names come from var.hub_network — the platform team must
  # provision the hub (provision_hub) before app teams order spokes.
  spoke_hub = {
    subscription_id     = var.azure_connectivity_subscription_id
    scope               = local.connectivity_scope
    resource_group_name = var.hub_network.hub_resource_group_name
    vnet_name           = var.hub_network.hub_vnet_name
  }
}

# ── Enterprise-Scale management group hierarchy ──
# This run creates the Landing Zones → Corp/Online/Sandbox (+ Connectivity) hierarchy under the
# user-provided parent management group. The platform module below builds its scopes from the group
# names (module outputs, so ordered after creation) rather than a data source, so creating and using
# them in the same run works (see modules/azure/meshstack_integration.tf).
module "management_groups" {
  source = "./modules/management-groups"

  name_prefix                = var.azure_management_groups.name_prefix
  parent_management_group_id = var.azure_management_groups.parent_management_group_id
  landing_zones_display_name = var.azure_management_groups.landing_zones_display_name
  corp_display_name          = var.azure_management_groups.corp_display_name
  online_display_name        = var.azure_management_groups.online_display_name
  sandbox_display_name       = var.azure_management_groups.sandbox_display_name
  connectivity_display_name  = var.azure_management_groups.connectivity_display_name
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
    name               = local.platform_name
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
# the parent management group (see module.management_groups / local.*_management_group).
module "azure_platform" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure?ref=${var.hub.git_ref}"

  azure_management_group              = local.lz_management_group
  resource_name_prefix                = var.azure_management_groups.name_prefix
  azure_subscription_provisioning     = local.azure_subscription_provisioning
  azure_subscription_owner_object_ids = var.azure_subscription_owner_object_ids

  landing_zones = {
    corp = {
      management_group_id = local.corp_management_group
      display_name        = "Azure Corp"
      description         = "Corp-connected landing zone: subscriptions are placed in the Corp management group for internal, hub-connected workloads. The Azure Spoke Network building block is mandatory here, giving every tenant routed connectivity to the hub."
      # Corp tenants must have a spoke network (hub connectivity) plus a budget alert.
      mandatory_building_block_definition_uuids = [
        module.spoke_network.building_block_definition.uuid,
        module.budget_alert.building_block_definition.uuid,
      ]
    }
    online = {
      management_group_id = local.online_management_group
      display_name        = "Azure Online"
      description         = "Internet-facing landing zone: subscriptions are placed in the Online management group for public-facing workloads without a mandatory hub connection."
      # Online tenants must have a budget alert.
      mandatory_building_block_definition_uuids = [
        module.budget_alert.building_block_definition.uuid,
      ]
    }
    sandbox = {
      management_group_id = local.sandbox_management_group
      display_name        = "Azure Sandbox"
      description         = "Experimentation landing zone: subscriptions are placed in the Sandbox management group with relaxed guardrails for trying things out."
      # Sandbox tenants must have a budget alert.
      mandatory_building_block_definition_uuids = [
        module.budget_alert.building_block_definition.uuid,
      ]
    }
  }

  meshstack = {
    owning_workspace_identifier = var.workspace
    platform_name               = local.platform_name
    location_name               = var.use_global_location ? "global" : meshstack_location.this.metadata.name
    tags                        = merge(local.tags.landingzone, local.owner_tags)
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
  backplane_name        = "${var.azure_management_groups.name_prefix}budget-alert"

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = local.tags.building_block
  }
  hub = var.hub
}

module "storage_account" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/storage-account?ref=${var.hub.git_ref}"

  azure_tenant_id       = var.azure_tenant_id
  azure_subscription_id = var.azure_platform_subscription_id
  azure_scope           = local.landing_zones_scope
  azure_location        = var.azure_location
  backplane_name        = "${var.azure_management_groups.name_prefix}storage-account"

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = local.tags.building_block
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
  backplane_name                  = "${var.azure_management_groups.name_prefix}spoke-network"

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = local.tags.building_block
  }
  hub = var.hub
}

# ── Optional foundation ──
# Provisioned per the provision_hub / assign_policies / foundation_resource_groups inputs. With all
# off/empty the architecture is just the meshStack-side wiring (platform, landing zones, building
# blocks above).

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
# by ordering an instance below (meshstack_building_block.hub), gated by var.provision_hub.
module "hub_network" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/hub-network?ref=${var.hub.git_ref}"

  azure_tenant_id                    = var.azure_tenant_id
  azure_connectivity_subscription_id = var.azure_connectivity_subscription_id
  azure_scope                        = local.connectivity_scope
  azure_location                     = var.azure_location
  backplane_name                     = "${var.azure_management_groups.name_prefix}hub-network"

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = local.tags.building_block
  }
  hub = var.hub
}

resource "meshstack_building_block" "hub" {
  lifecycle {
    enabled = local.hub_enabled

    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
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
      hub_resource_group_name = { value = jsonencode(var.hub_network.hub_resource_group_name) }
      hub_vnet_name           = { value = jsonencode(var.hub_network.hub_vnet_name) }
      address_space           = { value = jsonencode(var.hub_network.address_space) }
      create_gateway_subnet   = { value = jsonencode(var.hub_network.create_gateway_subnet) }
      deploy_firewall         = { value = jsonencode(var.hub_network.deploy_firewall) }
      firewall_sku_tier       = { value = jsonencode(var.hub_network.firewall_sku_tier) }
    }
  }
}
