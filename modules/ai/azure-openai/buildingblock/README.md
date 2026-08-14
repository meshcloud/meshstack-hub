---
name: Azure OpenAI Model Backend
supportedPlatforms:
  - ai
description: Registers an Azure OpenAI deployment as a model backend on the LiteLLM gateway, scoped to the tenant's team.
# The module talks only to the LiteLLM admin API. It creates nothing in Azure and receives the
# Azure OpenAI endpoint, key and deployment name as static inputs, so there is no cloud-side setup
# to perform ahead of time.
requiresBackplane: false
---

# Azure OpenAI Model Backend Building Block

This building block registers an existing Azure OpenAI deployment as a model entry on the LiteLLM
gateway. It is the Azure entry in the model layer of the AI platform architecture, next to
`stackit/model-serving` for STACKIT, and it is what makes the architecture's claim of two cloud
providers true.

The module is thin on purpose. It creates one `litellm_model` resource and no Azure resources at
all, which is why it declares `requiresBackplane: false` and needs no Azure identity. The platform
team creates the Azure OpenAI resource and its deployment once, outside this module, and passes the
endpoint, the key and the deployment name in as static inputs.

The `team_id` input scopes the entry to one LiteLLM team, so the gateway offers the model to that
tenant alone and attributes its spend to that team. In the AI landing zone the team ID comes from
the platform tenant ID that `ai/model-access` produces, so the application team fills in nothing.

Azure OpenAI addresses a **deployment**, not a model. The provider joins `custom_llm_provider` and
`base_model` into `azure/<base_model>`, so `azure_deployment_name` must carry the Azure deployment
name rather than the underlying model name.

Application teams keep calling the LiteLLM gateway. The Azure credential stays on the gateway, so
the platform team can rotate it without a change on the application side.

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
| [litellm_model.this](https://registry.terraform.io/providers/ncecere/litellm/2.0.1/docs/resources/model) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_deployment_name"></a> [azure\_deployment\_name](#input\_azure\_deployment\_name) | Name of the model deployment in the Azure OpenAI resource, for example 'gpt-4o'. Azure routes on the deployment name, not on the model name. | `string` | n/a | yes |
| <a name="input_azure_openai_api_key"></a> [azure\_openai\_api\_key](#input\_azure\_openai\_api\_key) | Key of the Azure OpenAI resource. LiteLLM stores it and sends it upstream in the 'api-key' header. | `string` | n/a | yes |
| <a name="input_azure_openai_api_version"></a> [azure\_openai\_api\_version](#input\_azure\_openai\_api\_version) | Azure OpenAI data plane API version. '2024-10-21' is the latest dated GA version of the inference API. | `string` | `"2024-10-21"` | no |
| <a name="input_azure_openai_endpoint"></a> [azure\_openai\_endpoint](#input\_azure\_openai\_endpoint) | Endpoint of the Azure OpenAI resource, for example 'https://my-aoai.openai.azure.com'. LiteLLM calls the deployment under this host. | `string` | n/a | yes |
| <a name="input_litellm_api_base"></a> [litellm\_api\_base](#input\_litellm\_api\_base) | Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. The provider talks to the admin API under this URL. | `string` | n/a | yes |
| <a name="input_litellm_api_key"></a> [litellm\_api\_key](#input\_litellm\_api\_key) | LiteLLM admin key the provider authenticates with. It needs permission to register models. | `string` | n/a | yes |
| <a name="input_mode"></a> [mode](#input\_mode) | What the deployment is used for. LiteLLM accepts 'chat', 'completion', 'embedding', 'audio\_speech', 'audio\_transcription', 'image\_generation', 'video\_generation', 'batch' and 'rerank'. | `string` | `"chat"` | no |
| <a name="input_model_name"></a> [model\_name](#input\_model\_name) | Name the model is offered under on the LiteLLM gateway. Application teams pass this name in the 'model' field of their requests. | `string` | n/a | yes |
| <a name="input_team_id"></a> [team\_id](#input\_team\_id) | ID of the LiteLLM team the model is registered for. Only that team can call the model. Leave unset to register the model for the whole gateway. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_base"></a> [api\_base](#output\_api\_base) | OpenAI-compatible base URL of the LiteLLM gateway, including the '/v1' suffix. Calls to this model go here, not to the Azure endpoint. |
| <a name="output_model_id"></a> [model\_id](#output\_model\_id) | ID LiteLLM gave the model entry. |
| <a name="output_model_name"></a> [model\_name](#output\_model\_name) | Name to pass in the 'model' field of a request to the gateway. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with the model name and the endpoint to call it on. |
<!-- END_TF_DOCS -->
