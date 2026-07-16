---
name: STACKIT Network
supportedPlatforms:
  - stackit
description: Creates a routed STACKIT network inside an existing STACKIT project.
---

# STACKIT Network Building Block

This building block module creates a routed STACKIT network inside an existing STACKIT
project. The network automatically draws its addressing from the network area the project was
placed into at creation time (via the project's `networkArea` label) — no separate
network-area or routing configuration is needed here.

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
| [stackit_network.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ipv4_nameservers"></a> [ipv4\_nameservers](#input\_ipv4\_nameservers) | IPv4 nameservers for the network. Empty list falls back to the project's network area default nameservers. | `list(string)` | `[]` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the STACKIT network. | `string` | n/a | yes |
| <a name="input_network_prefix_length"></a> [network\_prefix\_length](#input\_network\_prefix\_length) | IPv4 prefix length for the network (24-28). | `number` | `25` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID (existing project) in which the network will be created. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account for WIF-based authentication. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_network_cidr"></a> [network\_cidr](#output\_network\_cidr) | Allocated IPv4 CIDR block of the network. |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | The UUID of the created STACKIT network. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created network. |
<!-- END_TF_DOCS -->