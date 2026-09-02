output "identity" {
  value = {
    client_id    = azurerm_user_assigned_identity.bootstrap.client_id
    principal_id = azurerm_user_assigned_identity.bootstrap.principal_id
    tenant_id    = azurerm_user_assigned_identity.bootstrap.tenant_id
  }
  description = "The bootstrap managed identity meshStack runs the reference architecture as. Wire `client_id` into the building block definition's ARM_CLIENT_ID input."
}
