data "azurerm_client_config" "spoke" {
  provider = azurerm.spoke
}

#
# 1. deploy the resource group
#

resource "azurerm_resource_group" "spoke_rg" {
  provider = azurerm.spoke

  name     = var.spoke_rg_name
  location = var.location
}

#
# 2.assign permission to deploy resource in that specific RG
#
resource "azurerm_role_assignment" "spoke_rg" {
  provider = azurerm.spoke

  role_definition_name = "Owner"
  principal_id         = coalesce(var.spoke_owner_principal_id, data.azurerm_client_config.spoke.object_id)
  scope                = azurerm_resource_group.spoke_rg.id
}

#
# 3. deploy the actual network
#
# Azure is eventually consistent: the Owner role assignment above is not always
# effective immediately, which previously caused a 403 on the vnet read/create.
# Rather than sleeping, the pre-run script (prerun.sh) applies the role
# assignment and this vnet as separate, targeted `tofu apply -target` steps
# before the main run. Each targeted apply is a hard boundary, so by the time
# the main run creates the peering, the assignment has propagated and the vnet
# is committed. See the building block's pre_run_script in meshstack_integration.tf.
resource "azurerm_virtual_network" "spoke_vnet" {
  provider   = azurerm.spoke
  depends_on = [azurerm_role_assignment.spoke_rg]

  name                = "${var.name}-vnet"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  address_space       = [var.address_space]
}

#
# 4. establish the peering
#
data "azurerm_resource_group" "hub_rg" {
  provider = azurerm.hub
  name     = var.hub_rg
}

data "azurerm_virtual_network" "hub_vnet" {
  provider = azurerm.hub

  name                = var.hub_vnet
  resource_group_name = data.azurerm_resource_group.hub_rg.name
}

resource "azurerm_virtual_network_peering" "spoke_hub_peer" {
  provider = azurerm.spoke

  name                      = var.name
  resource_group_name       = azurerm_resource_group.spoke_rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id
}

resource "azurerm_virtual_network_peering" "hub_spoke_peer" {
  provider = azurerm.hub

  name                      = var.name
  resource_group_name       = data.azurerm_resource_group.hub_rg.name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnet.id
}
