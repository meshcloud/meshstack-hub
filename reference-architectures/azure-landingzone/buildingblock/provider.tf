# The ordered run authenticates as a service principal the platform engineer supplies when ordering
# (client id + secret + tenant, entered in the meshStack UI — see the azure_client_* inputs). That
# principal needs Owner on the scope the management groups are created under and the Microsoft Graph
# app roles to register the meshStack platform service principals, because this run creates the
# management groups, the platform service principals, management-group role assignments and the
# per-building-block backplane identities. The secret is the Azure equivalent of the STACKIT service
# account key: a sensitive input, reused on every run and rotatable from the UI.
provider "azurerm" {
  features {}
  subscription_id = var.azure_platform_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
}

provider "azuread" {
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id     = var.azure_tenant_id
}
