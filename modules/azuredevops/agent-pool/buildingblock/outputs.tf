output "agent_pool_id" {
  description = "ID of the created Azure DevOps agent pool"
  value       = azuredevops_elastic_pool.main.id
}

output "agent_pool_name" {
  description = "Name of the created Azure DevOps agent pool"
  value       = azuredevops_elastic_pool.main.name
}

output "elastic_pool_id" {
  description = "ID of the elastic pool configuration"
  value       = azuredevops_elastic_pool.main.id
}

output "vmss_id" {
  description = "Azure Resource ID of the VMSS"
  value       = data.azurerm_virtual_machine_scale_set.existing.id
}

output "agent_queue_id" {
  description = "ID of the agent queue in the project"
  value       = var.project_id != null ? azuredevops_agent_queue.main[0].id : null
}

output "max_capacity" {
  description = "Maximum capacity of the elastic pool"
  value       = azuredevops_elastic_pool.main.max_capacity
}

output "desired_idle" {
  description = "Number of desired idle agents"
  value       = azuredevops_elastic_pool.main.desired_idle
}
