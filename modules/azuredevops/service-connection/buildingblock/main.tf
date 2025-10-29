data "azurerm_key_vault" "devops" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "azure_devops_pat" {
  name         = var.pat_secret_name
  key_vault_id = data.azurerm_key_vault.devops.id
}

data "azurerm_subscription" "target" {
  subscription_id = var.azure_subscription_id
}

data "azurerm_client_config" "current" {}

resource "azuread_application" "service_connection" {
  display_name = var.service_connection_name
  description  = "Service principal for Azure DevOps service connection to subscription ${var.azure_subscription_id}"
}

resource "azuread_service_principal" "service_connection" {
  client_id = azuread_application.service_connection.client_id
}

resource "azuread_application_password" "service_connection" {
  application_id = azuread_application.service_connection.id
  display_name   = "Azure DevOps Service Connection Secret"
}

resource "azurerm_role_assignment" "service_connection" {
  scope                = data.azurerm_subscription.target.id
  role_definition_name = var.azure_role
  principal_id         = azuread_service_principal.service_connection.object_id
}

resource "azuredevops_serviceendpoint_azurerm" "main" {
  project_id            = var.project_id
  service_endpoint_name = var.service_connection_name
  description           = var.description

  credentials {
    serviceprincipalid  = azuread_service_principal.service_connection.client_id
    serviceprincipalkey = azuread_application_password.service_connection.value
  }

  azurerm_spn_tenantid      = data.azurerm_client_config.current.tenant_id
  azurerm_subscription_id   = data.azurerm_subscription.target.subscription_id
  azurerm_subscription_name = data.azurerm_subscription.target.display_name

  lifecycle {
    ignore_changes = [
      description
    ]
  }
}

resource "azuredevops_resource_authorization" "main" {
  count = var.authorize_all_pipelines ? 1 : 0

  project_id  = var.project_id
  resource_id = azuredevops_serviceendpoint_azurerm.main.id
  authorized  = true
  type        = "endpoint"
}
