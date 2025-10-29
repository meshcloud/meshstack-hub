provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "azuredevops" {
  org_service_url       = var.azuredevops_org_url
  personal_access_token = var.azuredevops_pat
}
