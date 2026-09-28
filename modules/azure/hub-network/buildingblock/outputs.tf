output "resource_group_name" {
  value       = azurerm_resource_group.hub.name
  description = "Name of the hub resource group."
}

output "vnet_id" {
  value       = azurerm_virtual_network.hub.id
  description = "Azure resource ID of the hub virtual network."
}

output "vnet_name" {
  value       = azurerm_virtual_network.hub.name
  description = "Name of the hub virtual network. Spoke networks peer into this vnet."
}

output "firewall_private_ip" {
  value       = var.deploy_firewall ? azurerm_firewall.hub[0].ip_configuration[0].private_ip_address : null
  description = "Private IP of the Azure Firewall, if deployed. Spokes route egress traffic here."
}

output "summary" {
  description = "Markdown summary of the created hub network."
  value       = <<-EOT
    # Azure Hub Network: **${azurerm_virtual_network.hub.name}**

    | Property | Value |
    |----------|-------|
    | **Resource Group** | `${azurerm_resource_group.hub.name}` |
    | **Hub VNet** | `${azurerm_virtual_network.hub.name}` (`${var.address_space}`) |
    | **Firewall** | ${var.deploy_firewall ? "deployed (${var.firewall_sku_tier})" : "not deployed"} |
    %{if var.deploy_firewall~}
    | **Firewall Private IP** | `${azurerm_firewall.hub[0].ip_configuration[0].private_ip_address}` |
    %{endif~}

    Spoke networks peer into `${azurerm_virtual_network.hub.name}`.
  EOT
}
