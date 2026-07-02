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
  description = "The ID of the Virtual Network"
  value       = local.create_vnet ? azurerm_virtual_network.vnet[0].id : data.azurerm_virtual_network.existing[0].id
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = local.effective_vnet_name
}

output "vnet_address_space" {
  description = "The address space of the Virtual Network"
  value       = local.create_vnet ? azurerm_virtual_network.vnet[0].address_space : data.azurerm_virtual_network.existing[0].address_space
}

output "workload_subnet_id" {
  description = "The ID of the workload subnet. Null when an existing VNet is used."
  value       = local.create_vnet ? azurerm_subnet.workload_subnet[0].id : null
}

output "connect_command" {
  description = "Ready-to-run az CLI commands to tunnel kubectl through Bastion to your AKS cluster."
  value       = <<-EOT
    # Terminal 1 — open the tunnel and keep it running
    az network bastion tunnel \
      --name ${azurerm_bastion_host.bastion.name} \
      --resource-group ${var.resource_group_name} \
      --target-resource-id ${coalesce(var.aks_cluster_resource_id, "<YOUR_AKS_CLUSTER_RESOURCE_ID>")} \
      --resource-port 443 \
      --port 8443
  EOT
}
