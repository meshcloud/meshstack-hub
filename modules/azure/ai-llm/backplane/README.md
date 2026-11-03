# Azure AI LLM — Backplane

Reference for platform engineers deploying this module.

## What it provisions

- A resource group and a **user-assigned managed identity** named after `name`, federated to the
  meshStack building block runner. No client secret exists.
- A custom role `<name>-deploy` at `scope`, typically the management group above all landing zones,
  allowing the identity to manage resource groups, AI Services accounts and model deployments, and
  to purge soft-deleted accounts.
- The role assignment of that role to the identity, with an **ABAC condition**: the identity may
  only create or delete role assignments of `Cognitive Services OpenAI User`. That is how a building
  block grants the application team's identity access to the model without the deploy identity
  being able to escalate its own privileges.

## Before application teams order

- **Quota.** The tokens-per-minute capacity a building block requests comes from the quota of the
  subscription it is ordered into, per model, region and deployment type. Azure assigns that quota
  by quota tier: a new subscription starts in tier 0, which only has `GlobalStandard` quota for a
  few small models, and moves up with usage. The default `azure_models` and `azure_deployment_sku`
  are what tier 0 covers, so an order works in a brand-new landing zone. A model or deployment type
  outside that, `DataZoneStandard` for EU data residency included, fails with `InsufficientQuota`
  (`0 / 0`) until the subscription reaches a higher tier or Microsoft approves a quota request.
  Quota requests take Microsoft's request form; there is no API for them.
- **Models and region.** Every model the integration offers must be available in `azure_location`
  for the chosen deployment type. Check the model availability table of Azure OpenAI before adding
  a model.
- **Delegation conditions.** Assigning the deploy role with a condition requires the deploying
  principal to hold `Owner` or `Role Based Access Control Administrator` at `scope`.

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
| [azurerm_role_definition.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_user_assigned_identity.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_role_definition.openai_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/role_definition) | data source |

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
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignment are applied. |
<!-- END_TF_DOCS -->
