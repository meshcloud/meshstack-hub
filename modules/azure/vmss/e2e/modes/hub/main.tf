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

locals {
  location = "germanywestcentral"
}

module "vmss" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure Virtual Machine Scale Set"

  azure_tenant_id = var.test_context.fixtures.azure.entra_tenant_id
  azure_scope     = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"
  azure_location  = local.location
  backplane_name  = "${var.test_context.run_id}-vmss-bp"
}

# The building block needs an existing subnet; a landing zone would get it from the spoke network.
resource "azurerm_resource_group" "network" {
  name     = "${var.test_context.run_id}-vmss-net"
  location = local.location
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.test_context.run_id}-vnet"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "this" {
  name                 = "vmss"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/26"]
}

output "version_ref" {
  value = module.vmss.building_block_definition.version_ref
}

output "network" {
  value = {
    resource_group_name = azurerm_resource_group.network.name
    vnet_name           = azurerm_virtual_network.this.name
    subnet_name         = azurerm_subnet.this.name
  }
}
