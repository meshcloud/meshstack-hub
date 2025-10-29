output "vmss_id" {
  description = "ID of the Virtual Machine Scale Set"
  value       = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].id : azurerm_windows_virtual_machine_scale_set.vmss[0].id
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = var.vmss_name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.vmss_rg.name
}

output "principal_id" {
  description = "Principal ID of the system-assigned managed identity"
  value       = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].identity[0].principal_id : azurerm_windows_virtual_machine_scale_set.vmss[0].identity[0].principal_id
}

output "load_balancer_id" {
  description = "ID of the load balancer (if enabled)"
  value       = var.enable_load_balancer ? azurerm_lb.vmss_lb[0].id : null
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer (if enabled)"
  value       = var.enable_load_balancer && var.enable_public_ip ? azurerm_public_ip.lb_public_ip[0].ip_address : null
}

output "backend_address_pool_id" {
  description = "ID of the backend address pool (if load balancer is enabled)"
  value       = var.enable_load_balancer ? azurerm_lb_backend_address_pool.vmss_backend_pool[0].id : null
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.vmss_vnet.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = azurerm_subnet.vmss_subnet.id
}

output "autoscale_setting_id" {
  description = "ID of the autoscale setting (if autoscaling is enabled)"
  value       = var.enable_autoscaling ? azurerm_monitor_autoscale_setting.vmss_autoscale[0].id : null
}

output "location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.vmss_rg.location
}
