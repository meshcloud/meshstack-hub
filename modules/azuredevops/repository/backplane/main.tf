data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

resource "azuread_application" "azure_devops" {
  display_name = var.service_principal_name
  description  = "Service principal for managing Azure DevOps repositories"
}

resource "azuread_service_principal" "azure_devops" {
  client_id = azuread_application.azure_devops.client_id
}

resource "azurerm_resource_group" "devops" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_key_vault" "devops" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azuread_service_principal.azure_devops.object_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }
}

resource "azurerm_role_definition" "azure_devops_manager" {
  name        = "${var.service_principal_name}-manager"
  description = "Allows management of Azure DevOps repositories"
  scope       = var.scope

  permissions {
    actions = [
      "Microsoft.KeyVault/vaults/secrets/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read"
    ]
  }
}

resource "azurerm_role_assignment" "azure_devops_manager" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.azure_devops_manager.role_definition_resource_id
  principal_id       = azuread_service_principal.azure_devops.object_id
}
