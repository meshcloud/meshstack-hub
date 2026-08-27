# Both providers authenticate as the same backplane UAMI via workload identity
# federation (ARM_CLIENT_ID / ARM_USE_OIDC / ARM_OIDC_TOKEN_FILE_PATH env vars).
# They differ only in the target subscription: the spoke landing zone vs. the hub.
provider "azurerm" {
  features {}
  alias           = "spoke"
  subscription_id = var.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "hub"
  subscription_id = var.hub_subscription_id
}
