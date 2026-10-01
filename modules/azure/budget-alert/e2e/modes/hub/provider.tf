# The backplane only exists in hub mode, so azurerm is configured here rather than in the root.
# Foundation mode then never installs the azurerm provider at all.
#
# A module holding a provider block may not take `count`, `for_each` or `depends_on` — so keep those
# off the `module "definition"` block in the root.
provider "azurerm" {
  subscription_id = var.test_context.fixtures.azure.subscription_uuid
  tenant_id       = var.test_context.fixtures.azure.entra_tenant_id

  features {}
}
