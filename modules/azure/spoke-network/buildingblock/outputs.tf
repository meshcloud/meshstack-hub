output "vnet_id" {
  description = "The ID of the virtual network created by this module."
  value       = azurerm_virtual_network.spoke_vnet.id

}

output "summary" {
  description = "Markdown summary of the created spoke network and its hub peering."
  value       = <<-EOT
    # Spoke Network: **${azurerm_virtual_network.spoke_vnet.name}**

    Your spoke VNet has been created and peered into the central network hub.

    ## Details

    | Property | Value |
    |----------|-------|
    | **VNet Name** | `${azurerm_virtual_network.spoke_vnet.name}` |
    | **Address Space** | `${var.address_space}` |
    | **Resource Group** | `${azurerm_resource_group.spoke_rg.name}` |
    | **Location** | `${azurerm_resource_group.spoke_rg.location}` |
    | **VNet ID** | `${azurerm_virtual_network.spoke_vnet.id}` |
    | **Portal** | [Open in Azure Portal](https://portal.azure.com/#@${data.azurerm_client_config.spoke.tenant_id}/resource${azurerm_virtual_network.spoke_vnet.id}/overview) |

    ## Hub Peering

    The spoke is peered bidirectionally with the central hub.

    | Property | Value |
    |----------|-------|
    | **Hub VNet** | `${data.azurerm_virtual_network.hub_vnet.name}` |
    | **Hub Resource Group** | `${data.azurerm_resource_group.hub_rg.name}` |
    | **Peering (spoke → hub)** | `${azurerm_virtual_network_peering.spoke_hub_peer.name}` |
    | **Peering (hub → spoke)** | `${azurerm_virtual_network_peering.hub_spoke_peer.name}` |
  EOT
}