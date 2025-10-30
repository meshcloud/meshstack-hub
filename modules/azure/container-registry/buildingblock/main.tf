data "azurerm_subscription" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_resource_group" "acr" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  count               = var.private_endpoint_enabled && var.vnet_name == null ? 1 : 0
  name                = "${var.acr_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.acr.name
  tags                = var.tags
}

data "azurerm_virtual_network" "existing_vnet" {
  count               = var.private_endpoint_enabled && var.vnet_name != null ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

locals {
  vnet_id   = var.private_endpoint_enabled ? (var.vnet_name != null ? data.azurerm_virtual_network.existing_vnet[0].id : azurerm_virtual_network.vnet[0].id) : null
  vnet_name = var.private_endpoint_enabled ? (var.vnet_name != null ? var.vnet_name : azurerm_virtual_network.vnet[0].name) : null
}

resource "azurerm_subnet" "pe_subnet" {
  count                = var.private_endpoint_enabled && var.subnet_name == null ? 1 : 0
  name                 = "${var.acr_name}-pe-subnet"
  resource_group_name  = azurerm_resource_group.acr.name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.subnet_address_prefix]
}

data "azurerm_subnet" "existing_subnet" {
  count                = var.private_endpoint_enabled && var.subnet_name != null ? 1 : 0
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

locals {
  subnet_id = var.private_endpoint_enabled ? (var.subnet_name != null ? data.azurerm_subnet.existing_subnet[0].id : azurerm_subnet.pe_subnet[0].id) : null
}

resource "azurerm_container_registry" "acr" {
  name                          = "${var.acr_name}${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.acr.name
  location                      = var.location
  sku                           = var.sku
  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = var.public_network_access_enabled
  zone_redundancy_enabled       = var.zone_redundancy_enabled && var.sku == "Premium" ? true : false
  anonymous_pull_enabled        = var.anonymous_pull_enabled
  data_endpoint_enabled         = var.data_endpoint_enabled && var.sku == "Premium" ? true : false
  network_rule_bypass_option    = var.network_rule_bypass_option
  retention_policy_in_days      = var.sku == "Premium" && var.retention_days > 0 ? var.retention_days : null
  trust_policy_enabled          = var.sku == "Premium" ? var.trust_policy_enabled : false

  dynamic "network_rule_set" {
    for_each = length(var.allowed_ip_ranges) > 0 ? [1] : []
    content {
      default_action = "Deny"

      dynamic "ip_rule" {
        for_each = var.allowed_ip_ranges
        content {
          action   = "Allow"
          ip_range = ip_rule.value
        }
      }
    }
  }

  dynamic "georeplications" {
    for_each = var.sku == "Premium" ? var.georeplications : []
    content {
      location                  = georeplications.value.location
      zone_redundancy_enabled   = georeplications.value.zone_redundancy_enabled
      regional_endpoint_enabled = georeplications.value.regional_endpoint_enabled
      tags                      = var.tags
    }
  }

  tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
    }
  )
}

resource "azurerm_private_endpoint" "acr_pe" {
  count               = var.private_endpoint_enabled ? 1 : 0
  name                = "${var.acr_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.acr.name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "${var.acr_name}-psc"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = var.private_dns_zone_id == "System" ? [azurerm_private_dns_zone.acr_dns[0].id] : [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}

resource "azurerm_private_dns_zone" "acr_dns" {
  count               = var.private_endpoint_enabled && var.private_dns_zone_id == "System" ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.acr.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  count                 = var.private_endpoint_enabled && var.private_dns_zone_id == "System" ? 1 : 0
  name                  = "${var.acr_name}-dns-link"
  resource_group_name   = azurerm_resource_group.acr.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns[0].name
  virtual_network_id    = local.vnet_id
  tags                  = var.tags
}

data "azurerm_resource_group" "hub_rg" {
  count    = var.private_endpoint_enabled && var.hub_resource_group_name != null ? 1 : 0
  provider = azurerm.hub
  name     = var.hub_resource_group_name
}

data "azurerm_virtual_network" "hub_vnet" {
  count               = var.private_endpoint_enabled && var.hub_vnet_name != null ? 1 : 0
  provider            = azurerm.hub
  name                = var.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_rg[0].name
}

resource "azurerm_virtual_network_peering" "acr_to_hub" {
  count                     = var.private_endpoint_enabled && var.hub_vnet_name != null ? 1 : 0
  name                      = "${var.acr_name}-to-hub"
  resource_group_name       = azurerm_resource_group.acr.name
  virtual_network_name      = local.vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet[0].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_acr" {
  count                     = var.private_endpoint_enabled && var.hub_vnet_name != null ? 1 : 0
  provider                  = azurerm.hub
  name                      = "hub-to-${var.acr_name}"
  resource_group_name       = data.azurerm_resource_group.hub_rg[0].name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet[0].name
  remote_virtual_network_id = local.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.allow_gateway_transit_from_hub
  use_remote_gateways          = false
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.aks_managed_identity_principal_id != null ? 1 : 0
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = var.aks_managed_identity_principal_id
}
