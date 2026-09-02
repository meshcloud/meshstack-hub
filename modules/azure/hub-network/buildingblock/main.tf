resource "azurerm_resource_group" "hub" {
  name     = var.hub_resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = [var.address_space]
}

# GatewaySubnet — required by Azure for a VPN/ExpressRoute gateway, and a stable anchor even before
# a gateway is deployed. The name must be exactly "GatewaySubnet".
resource "azurerm_subnet" "gateway" {
  count = var.create_gateway_subnet ? 1 : 0

  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 2, 1)]
}

# ── Optional Azure Firewall ──
# When enabled, the hub gets an AzureFirewallSubnet (name is fixed by Azure), a static public IP,
# an Azure Firewall, and a route table with a default route pointing at the firewall so spokes can
# egress through it.

resource "azurerm_subnet" "firewall" {
  count = var.deploy_firewall ? 1 : 0

  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 2, 0)]
}

resource "azurerm_public_ip" "firewall" {
  count = var.deploy_firewall ? 1 : 0

  name                = "${var.hub_vnet_name}-fw-pip"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "hub" {
  count = var.deploy_firewall ? 1 : 0

  name                = "${var.hub_vnet_name}-fw"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  threat_intel_mode   = var.firewall_threat_intel_mode

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

resource "azurerm_route_table" "egress" {
  count = var.deploy_firewall ? 1 : 0

  name                = "${var.hub_vnet_name}-egress-rt"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }
}
