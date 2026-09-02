locals {
  # Accept either a bare management group name (e.g. the tenant ID for the tenant root group) or a
  # full resource path, and normalise to the full path azurerm expects for a parent.
  parent_id = startswith(var.parent_management_group_id, "/providers/Microsoft.Management/managementGroups/") ? var.parent_management_group_id : "/providers/Microsoft.Management/managementGroups/${var.parent_management_group_id}"

  # Explicit, deterministic management group names (IDs) — NOT Azure-generated GUIDs. This keeps the
  # names known at plan time, which is required because the platform module (meshplatform) does a
  # for_each over the landing-zones scope; an unknown (apply-time) name breaks that for_each.
  # `name_prefix` keeps them unique across the tenant (e.g. "<platform_identifier>-").
  lz_name           = "${var.name_prefix}landing-zones"
  corp_name         = "${var.name_prefix}corp"
  online_name       = "${var.name_prefix}online"
  sandbox_name      = "${var.name_prefix}sandbox"
  connectivity_name = "${var.name_prefix}connectivity"
}

# The "Landing Zones" management group holds the archetype groups and is the scope the platform's
# replicator/metering identities and the building block backplanes operate on.
resource "azurerm_management_group" "landing_zones" {
  name                       = local.lz_name
  display_name               = var.landing_zones_display_name
  parent_management_group_id = local.parent_id
}

resource "azurerm_management_group" "corp" {
  name                       = local.corp_name
  display_name               = var.corp_display_name
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "online" {
  name                       = local.online_name
  display_name               = var.online_display_name
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "sandbox" {
  name                       = local.sandbox_name
  display_name               = var.sandbox_display_name
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

# Connectivity management group — the hub subscription lives here; the hub-network backplane role is
# scoped to it. A sibling of Landing Zones under the same parent.
resource "azurerm_management_group" "connectivity" {
  name                       = local.connectivity_name
  display_name               = var.connectivity_display_name
  parent_management_group_id = local.parent_id
}
