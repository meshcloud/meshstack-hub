output "agent_pool_id" {
  description = "ID of the Azure DevOps agent pool"
  value       = azuredevops_agent_pool.vmss.id
}

output "agent_pool_name" {
  description = "Name of the Azure DevOps agent pool"
  value       = azuredevops_agent_pool.vmss.name
}

output "agent_queue_id" {
  description = "ID of the agent queue in the project"
  value       = azuredevops_agent_queue.vmss.id
}

output "elastic_pool_id" {
  description = "ID of the elastic pool configuration"
  value       = azuredevops_elastic_pool.vmss.id
}

output "vmss_id" {
  description = "ID of the Virtual Machine Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.vmss.id
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.vmss.name
}

output "vmss_principal_id" {
  description = "Managed identity principal ID of the VMSS"
  value       = azurerm_linux_virtual_machine_scale_set.vmss.identity[0].principal_id
}

output "subnet_id" {
  description = "ID of the subnet where VMSS is deployed"
  value       = data.azurerm_subnet.spoke.id
}
