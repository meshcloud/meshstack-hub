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

resource "azuredevops_serviceendpoint_azurerm" "main" {
  project_id            = var.project_id
  service_endpoint_name = var.service_connection_name
  description           = var.description

  credentials {
    serviceprincipalid  = var.service_principal_id
    serviceprincipalkey = var.service_principal_key
  }

  azurerm_spn_tenantid      = var.azure_tenant_id
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
