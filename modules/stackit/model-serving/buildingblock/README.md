---
name: STACKIT AI Model Serving Access
supportedPlatforms:
  - stackit
description: Issues a scoped STACKIT AI Model Serving API token so a tenant can call the sovereign LLM API.
---

# STACKIT AI Model Serving Access Building Block

This building block issues a STACKIT AI Model Serving API token scoped to a tenant's STACKIT project.
Each tenant gets its own token rather than sharing one token across the platform, so the platform
team can revoke a single tenant's access and read its usage separately.

The token authenticates calls against STACKIT's OpenAI-compatible inference endpoint. The `api_base`
output carries the full base URL including the `/v1` suffix, because a caller that drops the suffix
gets a "Not Found" error from the endpoint. Callers send the token as a bearer token in the
`Authorization` header, which is what LiteLLM's `api_key` field sends upstream — so registering this
endpoint as a LiteLLM backend needs nothing beyond the `api_base` and `token` outputs.

STACKIT parses `ttl_duration` with Go's duration parser, which knows no day unit. Write 90 days as
`2160h`; a value such as `90d` is rejected.

The module receives the service account it authenticates with as an input and reaches STACKIT
through workload identity federation, so it stores no long-lived key. The `backplane/` tier creates
that service account and grants it `model-serving.editor` on the folder holding the tenant projects
— see [backplane/README.md](../backplane/README.md) for the role and the scope.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.88.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_modelserving_token.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/modelserving_token) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID the Model Serving token is issued in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | STACKIT region for the Model Serving token. Defaults to the provider region. | `string` | `null` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account used to issue the Model Serving token. | `string` | n/a | yes |
| <a name="input_token_description"></a> [token\_description](#input\_token\_description) | Description shown on the Model Serving token. | `string` | `"Managed by meshStack."` | no |
| <a name="input_token_name"></a> [token\_name](#input\_token\_name) | Display name of the Model Serving token. | `string` | n/a | yes |
| <a name="input_ttl_duration"></a> [ttl\_duration](#input\_ttl\_duration) | Lifetime of the Model Serving token as a Go duration, e.g. '2160h' for 90 days. Valid units are 'ns', 'us', 'ms', 's', 'm' and 'h'. | `string` | `"2160h"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_base"></a> [api\_base](#output\_api\_base) | OpenAI-compatible base URL of the STACKIT inference endpoint, including the '/v1' suffix. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with the endpoint URL and the token. |
| <a name="output_token"></a> [token](#output\_token) | The STACKIT Model Serving API token. Shown only on creation. |
| <a name="output_token_id"></a> [token\_id](#output\_token\_id) | ID of the Model Serving token. |
| <a name="output_valid_until"></a> [valid\_until](#output\_valid\_until) | Expiry timestamp of the Model Serving token. |
<!-- END_TF_DOCS -->
