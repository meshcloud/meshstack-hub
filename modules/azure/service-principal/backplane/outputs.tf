output "identity" {
  description = "UAMI identity attributes consumed by meshstack_integration.tf as static inputs."
  value = {
    client_id    = azurerm_user_assigned_identity.buildingblock_deploy.client_id
    principal_id = azurerm_user_assigned_identity.buildingblock_deploy.principal_id
    tenant_id    = azurerm_user_assigned_identity.buildingblock_deploy.tenant_id
  }
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

output "tenant_id" {
  value       = data.azurerm_subscription.current.tenant_id
  description = "The tenant ID of the Azure subscription."
}
