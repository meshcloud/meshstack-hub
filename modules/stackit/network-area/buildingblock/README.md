---
name: STACKIT Network Area
supportedPlatforms:
  - stackit
description: Creates a STACKIT network area with a configurable IPv4 address plan for network-segmented projects.
---

# STACKIT Network Area Building Block

This building block module creates a STACKIT network area and its IPv4 region configuration
(address ranges, transfer network, prefix length bounds, and default nameservers), so that
STACKIT projects can be organized into network-segmented address spaces within an organization.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_network_area.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_area) | resource |
| [stackit_network_area_region.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_area_region) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_nameservers"></a> [default\_nameservers](#input\_default\_nameservers) | Default IPv4 nameservers assigned to networks created within the network area. | `list(string)` | n/a | yes |
| <a name="input_default_prefix_length"></a> [default\_prefix\_length](#input\_default\_prefix\_length) | Default prefix length used for networks created within the network area when none is specified. | `number` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the network area. | `map(string)` | n/a | yes |
| <a name="input_max_prefix_length"></a> [max\_prefix\_length](#input\_max\_prefix\_length) | Maximum prefix length allowed for networks created within the network area. | `number` | n/a | yes |
| <a name="input_min_prefix_length"></a> [min\_prefix\_length](#input\_min\_prefix\_length) | Minimum prefix length allowed for networks created within the network area. | `number` | n/a | yes |
| <a name="input_network_area_name"></a> [network\_area\_name](#input\_network\_area\_name) | Name of the STACKIT network area. | `string` | n/a | yes |
| <a name="input_network_ranges"></a> [network\_ranges](#input\_network\_ranges) | List of IPv4 CIDR ranges available to projects within the network area. | `list(string)` | n/a | yes |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization ID under which the network area will be created. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account for WIF-based authentication. | `string` | n/a | yes |
| <a name="input_transfer_network"></a> [transfer\_network](#input\_transfer\_network) | IPv4 CIDR range used as the transfer network between the network area and connected networks. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_network_area_id"></a> [network\_area\_id](#output\_network\_area\_id) | The UUID of the created STACKIT network area. |
| <a name="output_network_area_name"></a> [network\_area\_name](#output\_network\_area\_name) | The name of the created STACKIT network area. |
| <a name="output_network_ranges"></a> [network\_ranges](#output\_network\_ranges) | IPv4 CIDR ranges available to projects within the network area. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created network area. |
| <a name="output_transfer_network"></a> [transfer\_network](#output\_transfer\_network) | IPv4 CIDR range used as the transfer network between the network area and connected networks. |
<!-- END_TF_DOCS -->