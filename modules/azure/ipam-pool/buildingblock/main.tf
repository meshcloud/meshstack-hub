resource "azurerm_resource_group" "ipam" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_network_manager" "ipam" {
  name                = "${var.name}-avnm"
  location            = azurerm_resource_group.ipam.location
  resource_group_name = azurerm_resource_group.ipam.name
  description         = "Hosts the ${var.name} IPAM pool."

  scope {
    management_group_ids = startswith(var.network_manager_scope, "/providers/Microsoft.Management/") ? [var.network_manager_scope] : []
    subscription_ids     = startswith(var.network_manager_scope, "/subscriptions/") ? [var.network_manager_scope] : []
  }
}

resource "azurerm_network_manager_ipam_pool" "this" {
  name               = var.name
  display_name       = var.name
  location           = azurerm_resource_group.ipam.location
  network_manager_id = azurerm_network_manager.ipam.id
  address_prefixes   = [var.address_prefix]
}
