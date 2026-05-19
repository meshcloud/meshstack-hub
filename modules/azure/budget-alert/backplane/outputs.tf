output "identity" {
  value = {
    client_id    = azurerm_user_assigned_identity.buildingblock.client_id
    principal_id = azurerm_user_assigned_identity.buildingblock.principal_id
    tenant_id    = azurerm_user_assigned_identity.buildingblock.tenant_id
  }
  description = "The managed identity used as the automation principal for this building block."
}

output "role_definition_id" {
  value       = azurerm_role_definition.buildingblock_deploy.id
  description = "The ID of the role definition that enables deployment of the building block."
}

output "role_definition_name" {
  value       = azurerm_role_definition.buildingblock_deploy.name
  description = "The name of the role definition that enables deployment of the building block."
}

output "scope" {
  value       = var.scope
  description = "The scope where the role definition and role assignment are applied."
}
