provider "azurerm" {
  features {}
  # subscription_id targets the tenant's Azure subscription; authentication is provided via the
  # ARM_* OIDC/WIF environment inputs wired by meshstack_integration.tf.
  subscription_id = var.subscription_id
}
