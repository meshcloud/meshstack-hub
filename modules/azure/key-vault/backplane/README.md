# Azure Key Vault — Backplane

Sets up the identity the Azure Key Vault building block runs with.

## What it provisions

- A resource group named after `var.name`, holding a **user-assigned managed identity**.
- A **federated identity credential** per building block runner subject, so runs authenticate
  through workload identity federation. No client secret exists.
- A custom **deploy role** on `scope`, typically the management group above all landing zones:
  Key Vault, private endpoint, private DNS, vnet and resource group permissions in the tenant
  subscription.
- When `hub_scope` is set, a **hub peering role** on it, so private Key Vaults can peer their vnet
  into the hub vnet. The same identity peers both sides.

## Required permissions to deploy

- `Managed Identity Contributor` on the subscription the identity lives in.
- `User Access Administrator` (or `Owner`) on `scope` and, if set, `hub_scope`, to create the role
  definitions and assignments.

## Migrating from the service principal backplane

Earlier versions created an Entra application and service principal with a client secret or a
federated credential. This version replaces them with a managed identity. Applying it destroys the
service principals and their role assignments, and the building block definition must switch its
`ARM_CLIENT_ID` to the new identity — `meshstack_integration.tf` does that for you.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.65.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_resource_group.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.backplane_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.backplane_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_user_assigned_identity.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hub_scope"></a> [hub\_scope](#input\_hub\_scope) | Scope holding the hub vnet that private Key Vaults peer into (management group or subscription ID). Null grants no hub permissions, so the building block cannot peer. | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the UAMI resource. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the building block identity, its resource group and the role definitions. | `string` | `"key-vault"` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block can be deployed (management group or subscription ID), typically the parent of all landing zones. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer and subjects for federated authentication. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_hub_role_definition_id"></a> [hub\_role\_definition\_id](#output\_hub\_role\_definition\_id) | The ID of the role definition that enables peering into the hub vnet, or null without a hub. |
| <a name="output_hub_scope"></a> [hub\_scope](#output\_hub\_scope) | The scope where the hub peering role is applied, or null without a hub. |
| <a name="output_identity"></a> [identity](#output\_identity) | The managed identity used as the automation principal for this building block. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to landing zone subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to landing zone subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the deploy role definition and role assignment are applied. |
<!-- END_TF_DOCS -->
