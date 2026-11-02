variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string
      })
    })
  })
  nullable = false
}

provider "azurerm" {
  # Credentials come from the environment, WIF in CI. The backplane identity lives in the fixture
  # subscription, which also hosts the tenant the building block is ordered for.
  subscription_id = var.test_context.fixtures.azure.subscription_uuid
  tenant_id       = var.test_context.fixtures.azure.entra_tenant_id

  features {}
}

module "ai_model_endpoint" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure AI Model Endpoint"

  azure_tenant_id = var.test_context.fixtures.azure.entra_tenant_id
  azure_scope     = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"
  backplane_name  = "${var.test_context.run_id}-ai-bp"
}

# Stands in for the application's identity, the one the building block grants model access to.
resource "azurerm_resource_group" "app" {
  name     = "${var.test_context.run_id}-ai-app"
  location = "germanywestcentral"
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.test_context.run_id}-ai-app"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
}

output "version_ref" {
  value = module.ai_model_endpoint.building_block_definition.version_ref
}

output "app_principal_id" {
  value = azurerm_user_assigned_identity.app.principal_id
}
