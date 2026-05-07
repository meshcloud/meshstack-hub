provider "azurerm" {
  subscription_id = var.test_context.fixtures.azure.subscription_uuid
  tenant_id       = var.test_context.fixtures.azure.entra_tenant_id

  features {}
}

provider "azuread" {
  tenant_id = var.test_context.fixtures.azure.entra_tenant_id
}
