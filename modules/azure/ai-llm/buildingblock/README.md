---
name: Azure AI LLM
supportedPlatforms:
  - azure
description: |
  Deploys an approved AI model such as GPT-5 mini as a keyless, content-filtered Azure OpenAI endpoint in the tenant's subscription.
---

# Azure AI LLM

This module creates a resource group, an Azure AI Services account and one model deployment in the
tenant's subscription.

- **Keyless.** `local_auth_enabled = false`: the account accepts Entra ID tokens only. The optional
  `app_principal_id` is granted `Cognitive Services OpenAI User`, the role that may call models but
  not change the account.
- **Platform-curated models.** The platform team sets `models`, the allowed models with their
  versions, and `deployment_sku`, which decides where inference runs. The application team only
  picks a model and its capacity.
- **Content filter.** The deployment uses `Microsoft.DefaultV2`.
- **Quota.** `capacity` is taken from the subscription's quota for the model, region and deployment
  type. A run requesting more than is left fails with `InsufficientQuota`.
- **Clean deletion.** Deleting the building block purges the soft-deleted account, so the same name
  can be ordered again right away.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.65.0, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.3, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_cognitive_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account) | resource |
| [azurerm_cognitive_deployment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_principal_id"></a> [app\_principal\_id](#input\_app\_principal\_id) | Object ID of the identity the application calls the model with, such as a managed identity. It is granted `Cognitive Services OpenAI User` on the account. Null grants nothing. | `string` | `null` | no |
| <a name="input_capacity"></a> [capacity](#input\_capacity) | Rate limit of the deployment in thousands of tokens per minute. It is taken from the subscription's quota for the model, region and deployment type. | `number` | `10` | no |
| <a name="input_deployment_sku"></a> [deployment\_sku](#input\_deployment\_sku) | Deployment type of the model. `GlobalStandard` routes inference worldwide, `DataZoneStandard` keeps it inside the data zone of the region (EU or US), `Standard` inside the region itself. | `string` | `"GlobalStandard"` | no |
| <a name="input_location"></a> [location](#input\_location) | The Azure region of the AI Services account. Every model in `models` must be available there for `deployment_sku`. | `string` | n/a | yes |
| <a name="input_model_name"></a> [model\_name](#input\_model\_name) | The model to deploy, one of the keys of `models`. | `string` | n/a | yes |
| <a name="input_models"></a> [models](#input\_models) | Models the platform team allows, keyed by model name. Set by the platform team, the application team picks one of the keys as `model_name`. | <pre>map(object({<br/>    format  = optional(string, "OpenAI")<br/>    version = string<br/>  }))</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix of the resource group and the AI Services account. A random 5-character suffix is appended to the account for global uniqueness of its subdomain. | `string` | n/a | yes |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Whether the endpoint is reachable from the public internet. Entra ID still decides who may call it. Turn it off only when the application reaches the account through a private endpoint of its own. | `bool` | `true` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | The Azure subscription the endpoint is created in, the tenant's landing zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_name"></a> [account\_name](#output\_account\_name) | The name of the AI Services account, including its random suffix. |
| <a name="output_deployment_name"></a> [deployment\_name](#output\_deployment\_name) | The deployment name requests address the model by. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | The endpoint of the AI Services account. |
| <a name="output_model"></a> [model](#output\_model) | The deployed model and version. |
| <a name="output_openai_endpoint"></a> [openai\_endpoint](#output\_openai\_endpoint) | The endpoint OpenAI clients use as their Azure endpoint. |
| <a name="output_portal_url"></a> [portal\_url](#output\_portal\_url) | Azure Portal URL of the AI Services account. |
| <a name="output_resource_group"></a> [resource\_group](#output\_resource\_group) | The resource group containing the AI Services account. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
