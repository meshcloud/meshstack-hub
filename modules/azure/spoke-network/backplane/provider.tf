provider "azurerm" {
  features {}

  # The UAMI + its resource group are created in this subscription. Role
  # definitions/assignments are unaffected — they use their explicit `scope`.
  subscription_id = var.subscription_id
}
