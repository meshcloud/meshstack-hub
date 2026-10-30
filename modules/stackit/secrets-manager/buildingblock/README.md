---
name: STACKIT Secrets Manager
supportedPlatforms:
  - stackit
description: Provisions a STACKIT Secrets Manager instance.
---

# STACKIT Secrets Manager Building Block

This building block module provisions a STACKIT Secrets Manager instance, a Vault-compatible KV v2
secret store.

## Access for project members

`role_mapping` grants each meshStack project member STACKIT project roles, by default
`secrets-manager.reader` to Project Admins. The Secrets Manager accepts a STACKIT IAM access token
as Vault token (undocumented by STACKIT), so these members need no Secrets Manager user:

```sh
export VAULT_ADDR=https://prod.sm.eu01.stackit.cloud
export VAULT_TOKEN=$(stackit auth get-access-token)
vault kv list -mount=<instance id> /
```

The roles are project-wide: they open every Secrets Manager instance in the project.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_instance"></a> [instance](#module\_instance) | ./modules/secrets-manager-instance | n/a |

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_project_role_assignment.users](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_imports"></a> [imports](#input\_imports) | Existing Secrets Manager instance to take over, renamed to `instance_name` and with its access control list cleared; null creates one. | <pre>object({<br/>    instance_id = string<br/>  })</pre> | `null` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name of the Secrets Manager instance. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID of the tenant the Secrets Manager instance is created in. | `string` | n/a | yes |
| <a name="input_release_on_destroy"></a> [release\_on\_destroy](#input\_release\_on\_destroy) | Leave the instance in place on destroy. Cannot change once the instance is managed. | `bool` | `false` | no |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Maps meshStack project roles to STACKIT Secrets Manager project roles. Unknown roles are ignored. | `map(list(string))` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | Project users from meshStack, granted STACKIT roles through `role_mapping`. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | Vault-compatible API endpoint of the Secrets Manager. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the Secrets Manager instance. |
| <a name="output_instance_url"></a> [instance\_url](#output\_instance\_url) | STACKIT portal link to the Secrets Manager instance. |
| <a name="output_kv_mount"></a> [kv\_mount](#output\_kv\_mount) | Mount path of the instance's KV v2 secrets engine. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with connection details. |
<!-- END_TF_DOCS -->
