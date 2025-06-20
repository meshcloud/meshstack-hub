output "vnet_id" {
  description = "The ID of the virtual network created by this module."
  value       = azurerm_virtual_network.spoke_vnet.id

}