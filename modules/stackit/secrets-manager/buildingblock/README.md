---
name: STACKIT Secrets Manager
supportedPlatforms:
  - stackit
description: Provisions a STACKIT Secrets Manager instance.
---

# STACKIT Secrets Manager Building Block

This building block module provisions a STACKIT Secrets Manager instance, a Vault-compatible KV v2
secret store.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.82.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_secretsmanager_instance.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/secretsmanager_instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name of the Secrets Manager instance. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the Secrets Manager instance will be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | Vault-compatible API endpoint of the Secrets Manager. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the Secrets Manager instance. |
| <a name="output_kv_mount"></a> [kv\_mount](#output\_kv\_mount) | Mount path of the instance's KV v2 secrets engine. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with connection details. |
<!-- END_TF_DOCS -->
