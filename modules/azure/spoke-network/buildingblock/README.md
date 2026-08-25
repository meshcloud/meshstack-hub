---
name: Spoke VNet
supportedPlatforms:
  - azure
description: |
  Provides VNet for your Azure subscription that's connected on a central network hub.
---

The Connectivity building block deploys a managed spoke network that's connected to a central network hub.
This enables use cases like on-premise connectivity and managed internet egress via the central hub.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_resource_group.spoke_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.spoke_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_virtual_network.spoke_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.hub_spoke_peer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spoke_hub_peer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_client_config.spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.hub_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_virtual_network.hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | Address space of the virtual network in CIDR notation | `string` | n/a | yes |
| <a name="input_hub_rg"></a> [hub\_rg](#input\_hub\_rg) | Name of the resource group that contains the hub vnet to peer into. | `string` | n/a | yes |
| <a name="input_hub_subscription_id"></a> [hub\_subscription\_id](#input\_hub\_subscription\_id) | The ID of the subscription that hosts the hub vnet. | `string` | n/a | yes |
| <a name="input_hub_vnet"></a> [hub\_vnet](#input\_hub\_vnet) | Name of the hub vnet to peer the spoke into. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the spoke resource group and vnet are created. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | name of the virtual spoke network. This name is used as the basis to generate resource names for vnets and peerings. | `string` | n/a | yes |
| <a name="input_spoke_owner_principal_id"></a> [spoke\_owner\_principal\_id](#input\_spoke\_owner\_principal\_id) | Principal id that will become owner of the spokes. Defaults to the client\_id of the spoke azurerm provider. | `string` | `null` | no |
| <a name="input_spoke_rg_name"></a> [spoke\_rg\_name](#input\_spoke\_rg\_name) | name of the resource group to deploy for hosting the spoke vnet | `string` | `"connectivity"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | The ID of the subscription that you want to deploy the spoke to (used by the spoke azurerm provider). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary of the created spoke network and its hub peering. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | The ID of the virtual network created by this module. |
<!-- END_TF_DOCS -->