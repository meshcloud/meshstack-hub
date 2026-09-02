provider "azurerm" {
  features {}

  # The bootstrap identity + its resource group are created in this subscription. The Owner role
  # assignment is unaffected — it uses its explicit `scope`.
  subscription_id = var.subscription_id
}

# azuread is configured from ambient credentials (az login / ARM_* env) via required_providers —
# no explicit provider block needed (an empty one is deprecated in OpenTofu).
