output "bastion_host_id" {
  description = "The ID of the Azure Bastion Host"
  value       = azurerm_bastion_host.bastion.id
}

output "bastion_host_name" {
  description = "The name of the Azure Bastion Host"
  value       = azurerm_bastion_host.bastion.name
}

output "bastion_host_fqdn" {
  description = "The FQDN of the Azure Bastion Host"
  value       = azurerm_bastion_host.bastion.dns_name
}

output "bastion_public_ip" {
  description = "The public IP address of the Azure Bastion Host"
  value       = azurerm_public_ip.bastion_pip.ip_address
}

output "bastion_subnet_id" {
  description = "The ID of the AzureBastionSubnet"
  value       = azurerm_subnet.bastion_subnet.id
}

output "bastion_nsg_id" {
  description = "The ID of the Bastion Network Security Group"
  value       = azurerm_network_security_group.bastion_nsg.id
}

output "action_group_id" {
  description = "The ID of the central action group for notifications"
  value       = var.enable_observability ? azurerm_monitor_action_group.sandbox_alerts[0].id : null
}

output "action_group_name" {
  description = "The name of the central action group for notifications"
  value       = var.enable_observability ? azurerm_monitor_action_group.sandbox_alerts[0].name : null
}

output "service_health_alert_id" {
  description = "The ID of the service health alert"
  value       = var.enable_observability ? azurerm_monitor_activity_log_alert.service_health[0].id : null
}

output "bastion_resource_health_alert_id" {
  description = "The ID of the Bastion resource health alert"
  value       = var.enable_observability ? azurerm_monitor_activity_log_alert.bastion_resource_health[0].id : null
}

output "subscription_resource_health_alert_id" {
  description = "The ID of the subscription resource health alert"
  value       = var.enable_observability ? azurerm_monitor_activity_log_alert.subscription_resource_health[0].id : null
}

output "vnet_id" {
  description = "The ID of the POC Virtual Network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "The name of the POC Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "vnet_address_space" {
  description = "The address space of the POC Virtual Network"
  value       = azurerm_virtual_network.vnet.address_space
}

output "workload_subnet_id" {
  description = "The ID of workload subnet"
  value       = azurerm_subnet.workload_subnet.id
}
