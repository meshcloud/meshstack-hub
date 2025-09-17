output "role_definition_id" {
  description = "The ID of the created role definition"
  value       = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
}