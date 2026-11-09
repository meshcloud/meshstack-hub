data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "key_vault" {
  name     = var.key_vault_resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.vnet_name == null
  }

  name                = "${var.key_vault_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.key_vault.name
  tags                = var.tags

  depends_on = [azurerm_resource_group.key_vault]
}

data "azurerm_virtual_network" "existing_vnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.vnet_name != null
  }

  name                = var.vnet_name
  resource_group_name = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : var.key_vault_resource_group_name
}

locals {
  vnet_id   = var.private_endpoint_enabled ? (var.vnet_name != null ? data.azurerm_virtual_network.existing_vnet.id : azurerm_virtual_network.vnet.id) : null
  vnet_name = var.private_endpoint_enabled ? (var.vnet_name != null ? var.vnet_name : azurerm_virtual_network.vnet.name) : null
}

resource "azurerm_subnet" "pe_subnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.subnet_name == null
  }

  name                 = "${var.key_vault_name}-pe-subnet"
  resource_group_name  = azurerm_resource_group.key_vault.name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.subnet_address_prefix]

  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"

  depends_on = [azurerm_virtual_network.vnet]
}

data "azurerm_subnet" "existing_subnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.subnet_name != null
  }

  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : var.key_vault_resource_group_name
}

locals {
  subnet_id = var.private_endpoint_enabled ? (var.subnet_name != null ? data.azurerm_subnet.existing_subnet.id : azurerm_subnet.pe_subnet.id) : null
}

resource "azurerm_key_vault" "key_vault" {
  name                          = "${var.key_vault_name}-${random_string.resource_code.result}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.key_vault.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  enable_rbac_authorization     = true
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "key_vault_pe" {
  lifecycle {
    enabled = var.private_endpoint_enabled
  }

  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.key_vault.name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "${var.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.key_vault.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = var.private_dns_zone_id == "System" ? [azurerm_private_dns_zone.key_vault_dns.id] : [var.private_dns_zone_id]
    }
  }

  tags = var.tags

  depends_on = [azurerm_key_vault.key_vault]
}

resource "azurerm_private_dns_zone" "key_vault_dns" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.private_dns_zone_id == "System"
  }

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.key_vault.name
  tags                = var.tags

  depends_on = [azurerm_resource_group.key_vault]
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault_dns_link" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.private_dns_zone_id == "System"
  }

  name                  = "${var.key_vault_name}-dns-link"
  resource_group_name   = azurerm_resource_group.key_vault.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault_dns.name
  virtual_network_id    = local.vnet_id
  tags                  = var.tags

  depends_on = [
    azurerm_private_dns_zone.key_vault_dns,
    azurerm_private_endpoint.key_vault_pe
  ]
}

data "azurerm_resource_group" "hub_rg" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.hub_resource_group_name != null
  }

  provider = azurerm.hub
  name     = var.hub_resource_group_name
}

data "azurerm_virtual_network" "hub_vnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.hub_vnet_name != null
  }

  provider            = azurerm.hub
  name                = var.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

resource "azurerm_virtual_network_peering" "key_vault_to_hub" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.vnet_name == null && var.hub_vnet_name != null
  }

  name                      = "${var.key_vault_name}-to-hub"
  resource_group_name       = azurerm_resource_group.key_vault.name
  virtual_network_name      = local.vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_key_vault" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.vnet_name == null && var.hub_vnet_name != null
  }

  provider                  = azurerm.hub
  name                      = "hub-to-${var.key_vault_name}"
  resource_group_name       = data.azurerm_resource_group.hub_rg.name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = local.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.allow_gateway_transit_from_hub
  use_remote_gateways          = false
}
