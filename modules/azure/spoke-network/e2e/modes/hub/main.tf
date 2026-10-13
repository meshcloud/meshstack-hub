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

variable "ipam" {
  type        = bool
  nullable    = false
  description = "Builds the definition against an IPAM pool instead of a typed CIDR range."
}

provider "azurerm" {
  # Credentials come from the environment, WIF in CI. The fixture subscription hosts the backplane
  # identity, the hub, the pool and the tenant the building block is ordered for.
  subscription_id = var.test_context.fixtures.azure.subscription_uuid
  tenant_id       = var.test_context.fixtures.azure.entra_tenant_id

  features {}
}

locals {
  subscription_id = var.test_context.fixtures.azure.subscription_uuid
  location        = "germanywestcentral"

  ipam_resource_group_name = "${var.test_context.run_id}-ipam"
  network_manager_name     = "${var.test_context.run_id}-avnm"

  # Spelled out rather than read off the pool, which would leave the definition's inputs unknown
  # while planning. The building block only runs once everything in this module exists.
  ipam_pool_id = "/subscriptions/${local.subscription_id}/resourceGroups/${local.ipam_resource_group_name}/providers/Microsoft.Network/networkManagers/${local.network_manager_name}/ipamPools/${var.test_context.run_id}"
}

# A hub of its own per run, so concurrent runs never peer into each other's hub.
resource "azurerm_resource_group" "hub" {
  name     = "${var.test_context.run_id}-hub"
  location = local.location
}

resource "azurerm_virtual_network" "hub" {
  name                = "${var.test_context.run_id}-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.254.0.0/24"]
}

resource "azurerm_resource_group" "ipam" {
  lifecycle {
    enabled = var.ipam
  }

  name     = local.ipam_resource_group_name
  location = local.location
}

resource "azurerm_network_manager" "ipam" {
  lifecycle {
    enabled = var.ipam
  }
  depends_on = [azurerm_resource_group.ipam]

  name                = local.network_manager_name
  location            = local.location
  resource_group_name = local.ipam_resource_group_name

  scope {
    subscription_ids = ["/subscriptions/${local.subscription_id}"]
  }
}

resource "azurerm_network_manager_ipam_pool" "this" {
  lifecycle {
    enabled = var.ipam
  }
  depends_on = [azurerm_network_manager.ipam]

  name               = var.test_context.run_id
  location           = local.location
  network_manager_id = "/subscriptions/${local.subscription_id}/resourceGroups/${local.ipam_resource_group_name}/providers/Microsoft.Network/networkManagers/${local.network_manager_name}"
  address_prefixes   = ["10.200.0.0/16"]
}

module "spoke_network" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure Spoke Network"

  azure_tenant_id                 = var.test_context.fixtures.azure.entra_tenant_id
  azure_scope                     = "/subscriptions/${local.subscription_id}"
  azure_hub_scope                 = "/subscriptions/${local.subscription_id}"
  azure_hub_subscription_id       = local.subscription_id
  azure_backplane_subscription_id = local.subscription_id
  azure_hub_resource_group_name   = "${var.test_context.run_id}-hub"
  azure_hub_vnet_name             = "${var.test_context.run_id}-hub"
  azure_spoke_resource_group_name = "${var.test_context.run_id}-spoke"
  azure_location                  = local.location
  azure_ipam_pool_id              = var.ipam ? local.ipam_pool_id : null
  backplane_name                  = "${var.test_context.run_id}-spoke-bp"
}

output "version_ref" {
  value = module.spoke_network.building_block_definition.version_ref
}
