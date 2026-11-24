# Azure PostgreSQL Building Block — Backplane

This documentation is for platform engineers who deploy the backplane of the Azure PostgreSQL building block.

## Overview

The backplane creates what the building block runs need to deploy Azure Database for PostgreSQL Flexible Server into landing zone subscriptions:

- a resource group that holds the backplane identity
- a user-assigned managed identity that the building block runs log in as
- one federated identity credential for the current building block runner, and one for each trusted runner
- a custom role, assigned to the identity at `scope`

## Permissions

The custom role allows the identity to manage resource groups and PostgreSQL Flexible Servers in all
subscriptions under `scope`, typically the management group that holds all landing zones. It also
allows the identity to register resource providers.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.1.0, < 4.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_role_assignment.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | `"postgresql"` | no |
| <a name="input_principal_ids"></a> [principal\_ids](#input\_principal\_ids) | set of principal ids that will be granted permissions to deploy the building block | `set(string)` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block should be deployable, typically the parent of all Landing Zones. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | The IDs of the role assignments for the service principals. |
| <a name="output_role_assignment_principal_ids"></a> [role\_assignment\_principal\_ids](#output\_role\_assignment\_principal\_ids) | The principal IDs of the service principals that have been assigned the role. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignments are applied. |
<!-- END_TF_DOCS -->
