output "role_definition_id" {
  value       = azurerm_role_definition.buildingblock_deploy.id
  description = "The ID of the role definition that enables deployment of the building block to subscriptions."
}

output "role_definition_name" {
  value       = azurerm_role_definition.buildingblock_deploy.name
  description = "The name of the role definition that enables deployment of the building block to subscriptions."
}

output "role_assignment_ids" {
  value       = [for id in azurerm_role_assignment.buildingblock_deploy : id.id]
  description = "The IDs of the role assignments for the service principals."
}

output "role_assignment_principal_ids" {
  value       = [for id in azurerm_role_assignment.buildingblock_deploy : id.principal_id]
  description = "The principal IDs of the service principals that have been assigned the role."
}

output "scope" {
  value       = var.scope
  description = "The scope where the role definition and role assignments are applied."
}

output "hub_role_definition_id" {
  value       = azurerm_role_definition.buildingblock_deploy_hub.id
  description = "The ID of the role definition that enables deployment of the building block to the hub."
}

output "hub_role_definition_name" {
  value       = azurerm_role_definition.buildingblock_deploy_hub.name
  description = "The name of the role definition that enables deployment of the building block to the hub."
}

output "hub_role_assignment_ids" {
  value       = { for id in var.principal_ids : id => azurerm_role_assignment.buildingblock_deploy_hub[id].id }
  description = "The IDs of the hub role assignments for the service principals."
}

output "hub_role_assignment_principal_ids" {
  value       = { for id in var.principal_ids : id => azurerm_role_assignment.buildingblock_deploy_hub[id].principal_id }
  description = "The principal IDs of the service principals that have been assigned the hub role."
}
