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

# Azure still counts a deleted pool as nested for a while after its GET returns 404, so deleting the
# network manager right away fails with 409 CannotDeleteResource.
resource "time_sleep" "pool_deletion" {
  depends_on       = [azurerm_network_manager.ipam]
  destroy_duration = "3m"
}

resource "azurerm_network_manager_ipam_pool" "this" {
  depends_on = [time_sleep.pool_deletion]

  name               = var.name
  display_name       = var.name
  location           = azurerm_resource_group.ipam.location
  network_manager_id = azurerm_network_manager.ipam.id
  address_prefixes   = [var.address_prefix]
}
