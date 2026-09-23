---
name: STACKIT AI Model Serving
supportedPlatforms:
  - stackit
description: Mints a STACKIT Model Serving token, so applications on the platform can call a sovereign LLM.
---

# STACKIT AI Model Serving — Building Block

Enables `cloud.stackit.model-serving` on the tenant's STACKIT project and mints an inference token
inside it.

## What a consumer gets

One `access_credentials` output holding the endpoint, the token and the default model. The endpoint
speaks the OpenAI API, so any OpenAI client works against it by pointing its base URL there.

In the STACKIT Kubernetes Platform reference architecture these three values become a Kubernetes
secret named `stackit-ai` in every application namespace, with the keys `STACKIT_AI_BASE_URL`,
`STACKIT_AI_API_KEY` and `STACKIT_AI_MODEL`. The demo application reads them by that convention.

## Why the service is enabled first

`cloud.stackit.model-serving` is disabled on a fresh STACKIT project, and enabling it is
asynchronous. The block switches it on and then polls until the service reports `ENABLED`, because
minting a token against a service still reconciling fails.

## The token is not sensitive on the way out

meshStack building block outputs cannot be marked sensitive, so the token travels in the clear,
as the container registry credentials already do.

## Permissions

The run authenticates via Workload Identity Federation as the platform's STACKIT service account,
which needs `model-serving.token.create` and `service-enablement.service-state.edit`. `editor`
carries both; `model-serving.admin` carries the first but not the second.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.0, < 3.0.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [restapi_object.service_enablement](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [stackit_modelserving_token.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/modelserving_token) | resource |
| [terraform_data.service_enabled](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [external_external.stackit_access_token](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_model"></a> [model](#input\_model) | Model applications default to. Must be one the `/v1/models` endpoint serves. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project the model serving token is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the token and the inference endpoint live in. | `string` | n/a | yes |
| <a name="input_token_description"></a> [token\_description](#input\_token\_description) | Description of the model serving token. | `string` | n/a | yes |
| <a name="input_token_name"></a> [token\_name](#input\_token\_name) | Name of the model serving token, shown in the STACKIT portal. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_credentials"></a> [access\_credentials](#output\_access\_credentials) | Inference credentials: the endpoint, the token and the default model. |
| <a name="output_base_url"></a> [base\_url](#output\_base\_url) | OpenAI-compatible inference endpoint. |
| <a name="output_model"></a> [model](#output\_model) | Model applications default to. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown on the building block. |
<!-- END_TF_DOCS -->
