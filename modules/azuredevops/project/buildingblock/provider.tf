data "azurerm_key_vault" "devops" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "azure_devops_pat" {
  name         = var.pat_secret_name
  key_vault_id = data.azurerm_key_vault.devops.id
}

provider "azuredevops" {
  org_service_url       = var.azure_devops_organization_url
  personal_access_token = data.azurerm_key_vault_secret.azure_devops_pat.value
}
provider "azurerm" {
  features {}
}
