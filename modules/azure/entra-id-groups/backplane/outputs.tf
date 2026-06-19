output "identity" {
  description = "UAMI identity attributes consumed by meshstack_integration.tf as static inputs."
  value = {
    client_id    = azurerm_user_assigned_identity.this.client_id
    principal_id = azurerm_user_assigned_identity.this.principal_id
    tenant_id    = azurerm_user_assigned_identity.this.tenant_id
  }
}
