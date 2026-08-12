---
name: LiteLLM Team
supportedPlatforms:
  - ai
description: Creates the LiteLLM team of a tenant with a budget, and a virtual key scoped to that team.
# The module talks only to the LiteLLM admin API and receives the gateway URL and the admin key as
# static inputs, so there is no cloud-side setup to perform ahead of time.
requiresBackplane: false
---

# LiteLLM Team Building Block

This building block creates one LiteLLM team per tenant and one virtual key scoped to that team.
meshStack provisions it when a tenant in the AI landing zone is created, because the AI landing zone
lists the building block definition in `spec.mandatory_building_block_refs`. The application team
fills in nothing.

The team carries the budget. LiteLLM counts the spend of every key of a team against the team
budget, so one limit covers the tenant even when the platform team hands out a second key later.
The virtual key therefore sets no budget of its own.

The key omits `models` on purpose. The provider sends `all-team-models` to LiteLLM when `team_id`
is set and `models` is left out, so the model allow-list stays on the team alone and a landing zone
change reaches the key without recreating it.

LiteLLM returns the virtual key once, at creation, and never again. The `virtual_key` output is
marked sensitive and the `summary` output carries the key as well, so the value is available to the
application team on the building block run and nowhere else.

The `ncecere/litellm` provider is pinned to exactly `2.0.1`. This is a deliberate exception to the
hub rule that provider constraints use `>=`, and `versions.tf` explains why.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_litellm"></a> [litellm](#requirement\_litellm) | = 2.0.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [litellm_key.this](https://registry.terraform.io/providers/ncecere/litellm/2.0.1/docs/resources/key) | resource |
| [litellm_team.this](https://registry.terraform.io/providers/ncecere/litellm/2.0.1/docs/resources/team) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_budget_duration"></a> [budget\_duration](#input\_budget\_duration) | Length of one budget period, after which LiteLLM resets the spend counter. Written as a LiteLLM duration such as '30d', '7d' or '1h'. | `string` | `"30d"` | no |
| <a name="input_key_alias"></a> [key\_alias](#input\_key\_alias) | Alias of the virtual key. Leave unset to use '<team\_alias>-key'. | `string` | `null` | no |
| <a name="input_litellm_api_base"></a> [litellm\_api\_base](#input\_litellm\_api\_base) | Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. The provider talks to the admin API under this URL. | `string` | n/a | yes |
| <a name="input_litellm_api_key"></a> [litellm\_api\_key](#input\_litellm\_api\_key) | LiteLLM admin key the provider authenticates with. It needs permission to create teams and keys. | `string` | n/a | yes |
| <a name="input_max_budget"></a> [max\_budget](#input\_max\_budget) | Spending limit of the team for one budget period, in the currency the gateway reports spend in. LiteLLM blocks the team once the limit is reached. | `number` | `100` | no |
| <a name="input_meshstack_tenant_uuid"></a> [meshstack\_tenant\_uuid](#input\_meshstack\_tenant\_uuid) | UUID of the meshStack tenant. It is written to the team metadata so an operator can trace a LiteLLM team back to its tenant. | `string` | `""` | no |
| <a name="input_models"></a> [models](#input\_models) | Names of the models on the LiteLLM gateway that the team may call. An empty list sends no allow-list to LiteLLM. | `list(string)` | `[]` | no |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | Identifier of the meshStack project the tenant belongs to. It becomes part of the team alias and is written to the team metadata. | `string` | n/a | yes |
| <a name="input_team_alias"></a> [team\_alias](#input\_team\_alias) | Alias of the LiteLLM team. Leave unset to use '<workspace\_identifier>.<project\_identifier>'. | `string` | `null` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier of the meshStack workspace the tenant belongs to. It becomes part of the team alias and is written to the team metadata. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_base"></a> [api\_base](#output\_api\_base) | OpenAI-compatible base URL of the LiteLLM gateway, including the '/v1' suffix. |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | Hash of the virtual key. LiteLLM identifies the key by this value, and it is safe to show in logs. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with the endpoint, the virtual key and the budget. |
| <a name="output_team_alias"></a> [team\_alias](#output\_team\_alias) | Alias of the LiteLLM team, shown in the LiteLLM UI. |
| <a name="output_team_id"></a> [team\_id](#output\_team\_id) | ID of the LiteLLM team. meshStack uses it as the platform tenant ID, so later building blocks can bind resources to this team. |
| <a name="output_virtual_key"></a> [virtual\_key](#output\_virtual\_key) | The virtual key the application sends as a bearer token. LiteLLM returns it once, at creation, and never again. |
<!-- END_TF_DOCS -->
