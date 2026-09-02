# The onboarding run authenticates with ambient Azure credentials: `az login` when a platform
# engineer applies this locally, or `ARM_*` environment variables (workload identity federation)
# when an IaC runtime executes it. The identity needs Owner on the landing-zones management group
# and Entra Application Administrator, because the run creates the platform service principals,
# management-group role assignments and the building block backplane identities.
provider "azurerm" {
  features {}
  subscription_id = var.azure_platform_subscription_id
}

provider "azuread" {}
