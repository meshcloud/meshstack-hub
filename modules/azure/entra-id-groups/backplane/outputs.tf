output "identity" {
  description = "UAMI identity attributes consumed by meshstack_integration.tf as static inputs."
  value = {
    client_id    = azurerm_user_assigned_identity.backplane.client_id
    principal_id = azurerm_user_assigned_identity.backplane.principal_id
    tenant_id    = azurerm_user_assigned_identity.backplane.tenant_id
  }
}
