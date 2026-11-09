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
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.vnet_name == null
  }

  name                = "${var.acr_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.acr.name
  tags                = var.tags

  depends_on = [azurerm_resource_group.acr]
}

data "azurerm_virtual_network" "existing_vnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.vnet_name != null
  }

  name                = var.vnet_name
  resource_group_name = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : var.resource_group_name
}

locals {
  vnet_id   = var.private_endpoint_enabled && var.sku == "Premium" ? (var.vnet_name != null ? data.azurerm_virtual_network.existing_vnet.id : azurerm_virtual_network.vnet.id) : null
  vnet_name = var.private_endpoint_enabled && var.sku == "Premium" ? (var.vnet_name != null ? var.vnet_name : azurerm_virtual_network.vnet.name) : null
}

resource "azurerm_subnet" "pe_subnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.subnet_name == null
  }

  name                 = "${var.acr_name}-pe-subnet"
  resource_group_name  = azurerm_resource_group.acr.name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.subnet_address_prefix]

  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"

  depends_on = [azurerm_virtual_network.vnet]
}

data "azurerm_subnet" "existing_subnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.subnet_name != null
  }

  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : var.resource_group_name
}

locals {
  subnet_id = var.private_endpoint_enabled && var.sku == "Premium" ? (var.subnet_name != null ? data.azurerm_subnet.existing_subnet.id : azurerm_subnet.pe_subnet.id) : null
}

resource "azurerm_container_registry" "acr" {
  name                          = "${var.acr_name}${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.acr.name
  location                      = var.location
  sku                           = var.sku
  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = var.sku == "Premium" ? var.public_network_access_enabled : true
  zone_redundancy_enabled       = var.zone_redundancy_enabled && var.sku == "Premium" ? true : false
  anonymous_pull_enabled        = var.anonymous_pull_enabled
  data_endpoint_enabled         = var.data_endpoint_enabled && var.sku == "Premium" ? true : false
  network_rule_bypass_option    = var.network_rule_bypass_option
  retention_policy_in_days      = var.sku == "Premium" && var.retention_days > 0 ? var.retention_days : 0
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

  tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
    }
  )

  depends_on = [azurerm_resource_group.acr]
}

resource "azurerm_private_endpoint" "acr_pe" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium"
  }

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
      private_dns_zone_ids = var.private_dns_zone_id == "System" ? [azurerm_private_dns_zone.acr_dns.id] : [var.private_dns_zone_id]
    }
  }

  tags = var.tags

  depends_on = [azurerm_container_registry.acr]
}

resource "azurerm_private_dns_zone" "acr_dns" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.private_dns_zone_id == "System"
  }

  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.acr.name
  tags                = var.tags

  depends_on = [azurerm_resource_group.acr]
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.private_dns_zone_id == "System"
  }

  name                  = "${var.acr_name}-dns-link"
  resource_group_name   = azurerm_resource_group.acr.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = local.vnet_id
  tags                  = var.tags

  depends_on = [
    azurerm_private_dns_zone.acr_dns,
    azurerm_private_endpoint.acr_pe
  ]
}

data "azurerm_resource_group" "hub_rg" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.hub_resource_group_name != null
  }

  provider = azurerm.hub
  name     = var.hub_resource_group_name
}

data "azurerm_virtual_network" "hub_vnet" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.hub_vnet_name != null
  }

  provider            = azurerm.hub
  name                = var.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

resource "azurerm_virtual_network_peering" "acr_to_hub" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.vnet_name == null && var.hub_vnet_name != null
  }

  name                      = "${var.acr_name}-to-hub"
  resource_group_name       = azurerm_resource_group.acr.name
  virtual_network_name      = local.vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_acr" {
  lifecycle {
    enabled = var.private_endpoint_enabled && var.sku == "Premium" && var.vnet_name == null && var.hub_vnet_name != null
  }

  provider                  = azurerm.hub
  name                      = "hub-to-${var.acr_name}"
  resource_group_name       = data.azurerm_resource_group.hub_rg.name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = local.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.allow_gateway_transit_from_hub
  use_remote_gateways          = false
}

resource "azurerm_role_assignment" "acr_pull" {
  lifecycle {
    enabled = var.aks_managed_identity_principal_id != null
  }

  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = var.aks_managed_identity_principal_id
}
