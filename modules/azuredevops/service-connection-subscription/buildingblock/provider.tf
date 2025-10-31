provider "azuredevops" {
  org_service_url       = var.azure_devops_organization_url
  personal_access_token = data.azurerm_key_vault_secret.azure_devops_pat.value
}

provider "azurerm" {
  features {}
}

provider "azuread" {}
