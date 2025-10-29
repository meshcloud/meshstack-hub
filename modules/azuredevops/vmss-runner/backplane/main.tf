resource "azuread_application" "vmss_runner" {
  display_name = var.service_principal_name
}

resource "azuread_service_principal" "vmss_runner" {
  client_id = azuread_application.vmss_runner.client_id
}

resource "azuread_service_principal_password" "vmss_runner" {
  service_principal_id = azuread_service_principal.vmss_runner.id
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "vmss_runner" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azuread_service_principal.vmss_runner.object_id

    secret_permissions = [
      "Get",
      "List",
    ]
  }
}

resource "azurerm_key_vault_secret" "azuredevops_pat" {
  name         = var.azuredevops_pat_secret_name
  value        = var.azuredevops_pat
  key_vault_id = azurerm_key_vault.vmss_runner.id
}

resource "azurerm_key_vault_secret" "service_principal_client_secret" {
  name         = "service-principal-client-secret"
  value        = azuread_service_principal_password.vmss_runner.value
  key_vault_id = azurerm_key_vault.vmss_runner.id
}
