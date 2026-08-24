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
  description = "The ID of the role definition that enables deployment of the spoke network to landing zone subscriptions."
}

output "role_definition_name" {
  value       = azurerm_role_definition.backplane.name
  description = "The name of the role definition that enables deployment of the spoke network to landing zone subscriptions."
}

output "hub_role_definition_id" {
  value       = azurerm_role_definition.backplane_hub.id
  description = "The ID of the role definition that enables peering the spoke into the hub vnet."
}

output "hub_role_definition_name" {
  value       = azurerm_role_definition.backplane_hub.name
  description = "The name of the role definition that enables peering the spoke into the hub vnet."
}

output "scope" {
  value       = var.scope
  description = "The scope where the spoke deploy role definition and role assignment are applied."
}

output "hub_scope" {
  value       = var.hub_scope
  description = "The scope where the hub peering role definition and role assignment are applied."
}
