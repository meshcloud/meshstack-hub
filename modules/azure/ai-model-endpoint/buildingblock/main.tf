data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
}

locals {
  account_name = "${var.name}-${random_string.suffix.result}"
  model        = var.models[var.model_name]
  portal_url   = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${azurerm_cognitive_account.this.id}/overview"
}

resource "azurerm_cognitive_account" "this" {
  name                = local.account_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  kind                = "AIServices"
  sku_name            = "S0"

  # Entra ID tokens need a custom subdomain. With local auth off there are no API keys that could
  # leak, so access follows Azure RBAC alone.
  custom_subdomain_name = local.account_name
  local_auth_enabled    = false
}

resource "azurerm_cognitive_deployment" "this" {
  name                 = var.model_name
  cognitive_account_id = azurerm_cognitive_account.this.id

  # Microsoft's default content filter, set explicitly so it is visible in the code.
  rai_policy_name = "Microsoft.DefaultV2"

  model {
    format  = local.model.format
    name    = var.model_name
    version = local.model.version
  }

  sku {
    name     = var.deployment_sku
    capacity = var.capacity
  }
}

resource "azurerm_role_assignment" "app" {
  lifecycle {
    enabled = var.app_principal_id != null
  }

  scope                = azurerm_cognitive_account.this.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = var.app_principal_id
}
