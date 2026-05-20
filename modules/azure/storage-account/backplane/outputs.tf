output "identity" {
  value = {
    client_id    = azurerm_user_assigned_identity.backplane.client_id
    principal_id = azurerm_user_assigned_identity.backplane.principal_id
    tenant_id    = azurerm_user_assigned_identity.backplane.tenant_id
  }
  description = "The managed identity used as the automation principal for this building block."
}

output "role_definition_id" {
  value       = azurerm_role_definition.backplane.id
  description = "The ID of the role definition that enables deployment of the building block to subscriptions."
}

output "role_definition_name" {
  value       = azurerm_role_definition.backplane.name
  description = "The name of the role definition that enables deployment of the building block to subscriptions."
}

output "scope" {
  value       = var.scope
  description = "The scope where the role definition and role assignment are applied."
}

