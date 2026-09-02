provider "azurerm" {
  features {}

  # The UAMI + its resource group are created in this subscription. The role
  # definition/assignment are unaffected — they use their explicit `scope`.
  subscription_id = var.subscription_id
}
