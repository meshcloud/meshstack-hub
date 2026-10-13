---
name: Azure IPAM Pool
supportedPlatforms:
  - azure
description: Provides a central IP address pool that spoke networks draw non-overlapping address ranges from.
---

This building block creates an Azure Virtual Network Manager with an IP address management (IPAM) pool.
Virtual networks inside the network manager's scope can then request a free address range of a given size
instead of having it planned by hand.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.37.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_network_manager.ipam](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager) | resource |
| [azurerm_network_manager_ipam_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_ipam_pool) | resource |
| [azurerm_resource_group.ipam](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_address_prefix"></a> [address\_prefix](#input\_address\_prefix) | Address range of the pool in CIDR notation, e.g. '10.100.0.0/16'. Spoke networks are carved out of this range. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the resource group, network manager and IPAM pool are created. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the IPAM pool. Also the basis for the network manager name. | `string` | n/a | yes |
| <a name="input_network_manager_scope"></a> [network\_manager\_scope](#input\_network\_manager\_scope) | Management group ('/providers/Microsoft.Management/managementGroups/<id>') or subscription ('/subscriptions/<guid>') the network manager governs. Only virtual networks inside this scope can draw address space from the pool. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group created to host the network manager and its IPAM pool. | `string` | `"ipam"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | The ID of the subscription that hosts the network manager and its IPAM pool. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address_prefix"></a> [address\_prefix](#output\_address\_prefix) | The address range the pool hands out. |
| <a name="output_ipam_pool_id"></a> [ipam\_pool\_id](#output\_ipam\_pool\_id) | The resource ID of the IPAM pool. Spoke networks reference it to draw their address space. |
| <a name="output_network_manager_id"></a> [network\_manager\_id](#output\_network\_manager\_id) | The resource ID of the network manager hosting the pool. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary of the created IPAM pool. |
<!-- END_TF_DOCS -->
