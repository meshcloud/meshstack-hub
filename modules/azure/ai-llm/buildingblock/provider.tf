# Authenticates as the backplane's managed identity via workload identity federation
# (ARM_CLIENT_ID / ARM_USE_OIDC / ARM_OIDC_TOKEN_FILE_PATH).
provider "azurerm" {
  features {
    cognitive_account {
      # A deleted account stays soft-deleted for 48 hours and blocks its custom subdomain, so an
      # order that is deleted and placed again with the same name would fail without the purge.
      purge_soft_delete_on_destroy = true
    }
  }
  subscription_id = var.subscription_id
}
