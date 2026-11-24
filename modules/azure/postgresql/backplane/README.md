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
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.65.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_federated_identity_credential.trusted_runner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
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
| <a name="input_trusted_runner_identities"></a> [trusted\_runner\_identities](#input\_trusted\_runner\_identities) | One entry per trusted runner, with the issuer, audience and subject of its tokens. The backplane creates one federated credential for each. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for a runner that no version uses. If the same apply changes the runner, the apply fails instead. | <pre>list(object({<br/>    runner_uuid = string<br/>    issuer      = string<br/>    audience    = string<br/>    subject     = string<br/>  }))</pre> | `[]` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer, audience and subjects for federated authentication. The audience defaults to the one meshStack runners use for Azure tokens. | <pre>object({<br/>    issuer   = string<br/>    audience = optional(string, "api://AzureADTokenExchange")<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | n/a |
<!-- END_TF_DOCS -->
