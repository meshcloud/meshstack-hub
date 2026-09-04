provider "azurerm" {
  features {}
  # subscription_id + OIDC/workload-identity auth are supplied via ARM_* environment variables
  # (see the STATIC is_environment inputs in ../meshstack_integration.tf).
}
