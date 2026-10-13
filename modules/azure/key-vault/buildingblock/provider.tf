# Both providers authenticate as the backplane's managed identity via workload identity federation
# (ARM_CLIENT_ID / ARM_USE_OIDC / ARM_OIDC_TOKEN_FILE_PATH). They differ only in the subscription:
# the tenant's landing zone vs. the hub.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azurerm" {
  features {}
  alias = "hub"
  # A provider is configured even when no hub resource uses it, so it falls back to the landing zone.
  subscription_id = coalesce(var.hub_subscription_id, var.subscription_id)
}
