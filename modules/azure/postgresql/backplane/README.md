# Azure PostgreSQL Building Block — Backplane

This documentation is intended as a reference for platform engineers deploying the PostgreSQL Building Block backplane.

## Overview

The backplane provisions the automation identity and permissions required to deploy Azure Database
for PostgreSQL Flexible Server on behalf of application teams. It creates a
**User-Assigned Managed Identity (UAMI)** with a **federated identity credential** so meshStack can
authenticate via workload identity federation (WIF) — no service principals or client secrets.

## Permissions

The UAMI is granted a custom role definition scoped to `var.scope` (typically the top-level
management group for landing zones) that allows managing PostgreSQL Flexible Servers and their
resource groups, plus registering the required resource providers on freshly created subscriptions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.64 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_resource_group.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_user_assigned_identity.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | Azure region for the UAMI resource. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the building block identity and role definition. | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope for role assignment (management group or subscription ID). | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer and subjects for federated authentication. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | The managed identity used as the automation principal for this building block. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignment are applied. |
<!-- END_TF_DOCS -->
