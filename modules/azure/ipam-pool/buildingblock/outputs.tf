output "ipam_pool_id" {
  description = "The resource ID of the IPAM pool. Spoke networks reference it to draw their address space."
  value       = azurerm_network_manager_ipam_pool.this.id
}

output "network_manager_id" {
  description = "The resource ID of the network manager hosting the pool."
  value       = azurerm_network_manager.ipam.id
}

output "address_prefix" {
  description = "The address range the pool hands out."
  value       = var.address_prefix
}

output "summary" {
  description = "Markdown summary of the created IPAM pool."
  value       = <<-EOT
    # IPAM Pool: **${azurerm_network_manager_ipam_pool.this.name}**

    The pool hands out non-overlapping address ranges from `${var.address_prefix}` to virtual networks in `${var.network_manager_scope}`.

    | Property | Value |
    |----------|-------|
    | **Address Range** | `${var.address_prefix}` |
    | **Network Manager** | `${azurerm_network_manager.ipam.name}` |
    | **Resource Group** | `${azurerm_resource_group.ipam.name}` |
    | **Location** | `${azurerm_resource_group.ipam.location}` |
    | **Pool ID** | `${azurerm_network_manager_ipam_pool.this.id}` |

    Set the pool ID as `azure_ipam_pool_id` of the Azure Spoke Network building block definition to let spokes draw their address space from this pool.
  EOT
}
