---
name: Azure Hub Network
supportedPlatforms:
  - azure
description: Provisions the central hub virtual network (resource group, hub vnet, GatewaySubnet and an optional Azure Firewall) that spoke networks peer into.
---

This building block provisions the **central hub** of a hub-and-spoke Azure network topology in the
platform's connectivity subscription: a resource group, the hub virtual network, a `GatewaySubnet`
for a future VPN/ExpressRoute gateway, and — optionally — an Azure Firewall with a static public IP
and an egress route table whose default route points at the firewall.

It is the counterpart to the [`spoke-network`](../../spoke-network) building block: application
teams order a spoke network into their own subscription, which peers into the hub vnet this building
block creates.

## 🎯 When to use it

Order this once per connectivity environment (e.g. per hub subscription) to establish the hub that
all spoke networks connect to. It is a platform-team building block, not an application-team one.

## Shared Responsibilities

| Responsibility | Platform Team | Application Team |
| -------------- | :-----------: | :--------------: |
| Provision and operate the hub vnet and firewall | ✅ | ❌ |
| Choose the hub address space and firewall SKU | ✅ | ❌ |
| Peer spoke networks into the hub | ✅ | ❌ |
| Order spoke networks and use the connectivity | ❌ | ✅ |

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_firewall.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall) | resource |
| [azurerm_public_ip.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_route_table.egress](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |
| [azurerm_subnet.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | Address space of the hub virtual network in CIDR notation, e.g. '10.0.0.0/22'. Must be large enough for the derived AzureFirewallSubnet and GatewaySubnet (a /22 gives four /24s). | `string` | n/a | yes |
| <a name="input_create_gateway_subnet"></a> [create\_gateway\_subnet](#input\_create\_gateway\_subnet) | Create a GatewaySubnet for a future VPN/ExpressRoute gateway. | `bool` | `true` | no |
| <a name="input_deploy_firewall"></a> [deploy\_firewall](#input\_deploy\_firewall) | Deploy an Azure Firewall into the hub, with an AzureFirewallSubnet, a static public IP and an egress route table with a default route pointing at the firewall. | `bool` | `false` | no |
| <a name="input_firewall_sku_tier"></a> [firewall\_sku\_tier](#input\_firewall\_sku\_tier) | Azure Firewall SKU tier. Only Standard and Premium are supported (Basic requires a separate management subnet and IP). | `string` | `"Standard"` | no |
| <a name="input_firewall_threat_intel_mode"></a> [firewall\_threat\_intel\_mode](#input\_firewall\_threat\_intel\_mode) | Azure Firewall threat intelligence mode: Off, Alert or Deny. | `string` | `"Alert"` | no |
| <a name="input_hub_resource_group_name"></a> [hub\_resource\_group\_name](#input\_hub\_resource\_group\_name) | Name of the resource group created in the connectivity subscription to host the hub vnet and firewall. | `string` | `"hub-network"` | no |
| <a name="input_hub_vnet_name"></a> [hub\_vnet\_name](#input\_hub\_vnet\_name) | Name of the central hub virtual network. Used as the basis for the firewall and route table resource names. | `string` | `"hub-vnet"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the hub resource group, vnet and firewall are created. | `string` | `"germanywestcentral"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_firewall_private_ip"></a> [firewall\_private\_ip](#output\_firewall\_private\_ip) | Private IP of the Azure Firewall, if deployed. Spokes route egress traffic here. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the hub resource group. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary of the created hub network. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | Azure resource ID of the hub virtual network. |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | Name of the hub virtual network. Spoke networks peer into this vnet. |
<!-- END_TF_DOCS -->
