---
name: T Cloud Public Network
supportedPlatforms:
  - otc
description: |
  Creates a VPC with one subnet in a T Cloud Public project, and optionally a NAT gateway for outbound internet access.
# The building block authenticates with the project building block's backplane user, which the
# composing reference architecture passes in; it provisions no cloud-side identity of its own.
requiresBackplane: false
---

# T Cloud Public Network Building Block

Creates a VPC and one subnet in the project this building block is ordered on, both named `name`.
With `snat_enabled`, it also creates a NAT gateway with an elastic IP and an SNAT rule for the
subnet, so servers without public IPs reach the internet.

It wraps the partner modules
[terraform-opentelekomcloud-vpc](https://github.com/iits-consulting/terraform-opentelekomcloud-vpc)
and
[terraform-opentelekomcloud-snat](https://github.com/iits-consulting/terraform-opentelekomcloud-snat),
pinned by tag.

The RDS and CCE building blocks look the network up by name, so the VPC and its subnet share the
name `name`. Keep it unique within the project.

## Authentication

The provider reads `OS_AUTH_URL`, `OS_DOMAIN_NAME`, `OS_ACCESS_KEY` and `OS_SECRET_KEY` from the
environment, which the meshStack integration sets. `project_id` is the tenant's project, so the
network is created there.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_opentelekomcloud"></a> [opentelekomcloud](#requirement\_opentelekomcloud) | >= 1.37.0, < 2.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_snat"></a> [snat](#module\_snat) | git::https://github.com/iits-consulting/terraform-opentelekomcloud-snat.git | v7.4.2 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | git::https://github.com/iits-consulting/terraform-opentelekomcloud-vpc.git | v7.4.2 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | IP range of the VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the VPC and of its subnet. The RDS and CCE building blocks find the network by this name. | `string` | `"app"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of the project the network is created in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | T Cloud Public region of the project. | `string` | `"eu-de"` | no |
| <a name="input_snat_enabled"></a> [snat\_enabled](#input\_snat\_enabled) | Creates a NAT gateway with an elastic IP, so that servers in the subnet reach the internet without public IPs of their own. | `bool` | `true` | no |
| <a name="input_subnet_cidr"></a> [subnet\_cidr](#input\_subnet\_cidr) | IP range of the subnet, inside `cidr_block`. | `string` | `"10.0.0.0/24"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_snat_ip"></a> [snat\_ip](#output\_snat\_ip) | Public IP the subnet's outbound traffic leaves through, or empty without a NAT gateway. |
| <a name="output_subnet_cidr"></a> [subnet\_cidr](#output\_subnet\_cidr) | IP range of the subnet. |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | Network ID of the subnet, as RDS instances and CCE clusters take it. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
