# Azure Hub Network — Backplane

Provisions the automation principal for the **Azure Hub Network** building block: a User-Assigned
Managed Identity (UAMI) federated to meshStack's workload identity federation, plus a custom role
definition and assignment at the connectivity scope that let it build and maintain the central hub.

## What it provisions

- **Resource group + UAMI** in the connectivity subscription (`subscription_id`), named after `name`.
- **Federated identity credentials** for the given WIF `subjects` so the building block run can
  authenticate as the UAMI without any stored secret.
- **`<name>-deploy` role definition + assignment** at `scope` (a management group or subscription —
  typically the platform Connectivity scope), granting management of the hub resource group, the
  hub vnet and its subnets, route tables, and the Azure Firewall with its public IPs.

## Required permissions

The identity applying this backplane needs, at `scope`, the ability to create custom role
definitions and role assignments (e.g. **Owner** or **User Access Administrator** + role definition
write), and **Managed Identity Contributor** in the connectivity subscription to create the UAMI.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.36.0 |

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
| <a name="input_scope"></a> [scope](#input\_scope) | Connectivity scope where the hub network can be deployed (management group or subscription ID). The deploy role definition and assignment are applied here. | `string` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Subscription (bare GUID) where the UAMI and its resource group are created. Typically the hub/connectivity subscription so the identity lives in a stable, platform-owned place. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer and subjects for federated authentication of the automation identity. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | The managed identity used as the automation principal for this building block. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the hub network to the connectivity scope. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the hub network to the connectivity scope. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the hub deploy role definition and role assignment are applied. |
<!-- END_TF_DOCS -->