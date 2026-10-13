# Azure IPAM Pool — Backplane

Sets up the automation identity the IPAM pool building block runs as.

## What it provisions

- A resource group and a user-assigned managed identity (UAMI) in `subscription_id`, federated with
  the meshStack building block runner.
- A custom role `<name>-deploy` at `scope`, assigned to the UAMI. It allows creating the resource
  group, the network manager and its IPAM pools, and reading the management groups and subscriptions
  the network manager is to govern.

## Before you deploy

- **Register `Microsoft.Network` at the management group** when `scope` is a management group. A
  network manager scoped to a management group fails to deploy otherwise:
  ```sh
  az provider register --namespace Microsoft.Network --management-group-id <management-group-id>
  ```
- The principal applying this backplane needs `Owner` (or `User Access Administrator` plus the right
  to create role definitions) at `scope`.

## Consumers of the pool

The identity of every building block that draws address space from the pool needs the built-in
**IPAM Pool User** role on the pool. The spoke network backplane (`modules/azure/spoke-network`)
grants it to its own identity at its hub scope, so keep the pool there.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.37.0, < 5.0.0 |

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
| <a name="input_location"></a> [location](#input\_location) | Azure region for the UAMI resource group. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the building block identity, resource group and role definition. | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope the IPAM pool building block deploys into and the network manager governs (management group or subscription ID). Typically the parent of the platform subscription and all landing zones. | `string` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Subscription (bare GUID) where the UAMI and its resource group are created. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer and subjects for federated authentication of the automation identity. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | The managed identity used as the automation principal for this building block. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the IPAM pool. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignment are applied. |
<!-- END_TF_DOCS -->
