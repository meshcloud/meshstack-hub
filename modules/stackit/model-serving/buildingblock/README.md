---
name: STACKIT AI Model Serving Access
supportedPlatforms:
  - stackit
description: Issues a scoped STACKIT AI Model Serving API token so a tenant can call the sovereign LLM API.
---

# STACKIT AI Model Serving Access Building Block

<!-- Scaffold: deliberately unfinished, not ready to publish as a building block. -->

This building block issues a STACKIT AI Model Serving API token scoped to a tenant's STACKIT project.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
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
| <a name="input_ttl_duration"></a> [ttl\_duration](#input\_ttl\_duration) | Lifetime of the Model Serving token, e.g. '90d'. | `string` | `"90d"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_token"></a> [token](#output\_token) | The STACKIT Model Serving API token. Shown only on creation. |
| <a name="output_token_id"></a> [token\_id](#output\_token\_id) | ID of the Model Serving token. |
| <a name="output_valid_until"></a> [valid\_until](#output\_valid\_until) | Expiry timestamp of the Model Serving token. |
<!-- END_TF_DOCS -->
