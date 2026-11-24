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
