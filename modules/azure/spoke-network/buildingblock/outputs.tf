output "vnet_id" {
  description = "The ID of the virtual network created by this module."
  value       = azurerm_virtual_network.spoke_vnet.id
}

output "address_space" {
  description = "The address space of the virtual network, as given or as allocated from the IPAM pool."
  value       = local.address_space
}

output "ipam_pool_portal_url" {
  description = "Azure Portal URL of the IPAM pool the address space was drawn from, or null without a pool."
  value       = local.ipam_pool_portal_url
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
    | **Address Space** | `${local.address_space}` |
    | **Resource Group** | `${azurerm_resource_group.spoke_rg.name}` |
    | **Location** | `${azurerm_resource_group.spoke_rg.location}` |
    | **VNet ID** | `${azurerm_virtual_network.spoke_vnet.id}` |
    | **Portal** | [Open in Azure Portal](https://portal.azure.com/#@${data.azurerm_client_config.spoke.tenant_id}/resource${azurerm_virtual_network.spoke_vnet.id}/overview) |%{if local.ipam_pool_portal_url != null}
    | **IPAM Pool** | [Open in Azure Portal](${local.ipam_pool_portal_url}) |%{endif}

    ## Hub Peering

    The spoke is peered bidirectionally with the central hub `${data.azurerm_virtual_network.hub_vnet.name}` (resource group `${data.azurerm_resource_group.hub_rg.name}`).

    | Direction | From | To |
    |-----------|------|----|
    | Spoke → Hub | `${azurerm_virtual_network.spoke_vnet.name}` | `${data.azurerm_virtual_network.hub_vnet.name}` |
    | Hub → Spoke | `${data.azurerm_virtual_network.hub_vnet.name}` | `${azurerm_virtual_network.spoke_vnet.name}` |
  EOT
}