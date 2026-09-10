---
name: meshStack NoOp Building Block
supportedPlatforms:
  - meshstack
description: |
  Reference building block demonstrating meshStack's complete Terraform interface:
  all input types, file inputs, user permissions injection, and pre-run scripts.
---
# meshStack NoOp Building Block

This building block is a reference implementation demonstrating how meshStack interfaces with OpenTofu building blocks. It exercises every input type, file input, pre-run script capability, and output type — without provisioning any cloud resources.

Use it to:

- Understand how meshStack passes inputs to Terraform
- Learn how FILE-type inputs are written to the working directory
- See how `USER_PERMISSIONS` injects project team members into your building block
- Understand the pre-run script execution model

## Input Types

| Input                   | Type                 | Assignment                       | Description                                                                                                        |
|-------------------------|----------------------|----------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `author`                | `CODE`               | `AUTHOR`                         | The principal that ordered the block, injected by meshStack                                                        |
| `user_permissions`      | `CODE`               | `USER_PERMISSIONS`               | Project team members and their roles as a structured list                                                          |
| `user_permissions_json` | `CODE`               | `USER_PERMISSIONS`               | Same as above, as a raw JSON string                                                                                |
| `workspace_identifier`  | `STRING`             | `WORKSPACE_IDENTIFIER`           | Identifier of the workspace the block belongs to, injected by meshStack                                            |
| `sensitive_yaml`        | `CODE`               | `STATIC` (sensitive)             | Encrypted YAML/JSON value, decrypted at runtime                                                                    |
| `static`                | `STRING`             | `STATIC`                         | A platform-engineer-defined string constant                                                                        |
| `static_code`           | `CODE`               | `STATIC`                         | A platform-engineer-defined map                                                                                    |
| `tag_value`             | `CODE`               | `TAG`                | Value of a meshStack tag, read from the target object rather than typed in by a user                               |
| `flag`                  | `BOOLEAN`            | `USER_INPUT`                     | Boolean flag chosen by the user                                                                                    |
| `num`                   | `INTEGER`            | `USER_INPUT`                     | Integer chosen by the user                                                                                         |
| `text`                  | `STRING`             | `USER_INPUT`                     | Free-text string from the user                                                                                     |
| `optional_text`         | `STRING`             | `USER_INPUT`                     | Optional string — can be omitted from the building block's inputs so the Terraform variable's default takes effect |
| `conditional_text`      | `STRING`             | `USER_INPUT`         | Only asked for while its `condition` holds (`input.flag == true`); hidden and unset otherwise                      |
| `deploy_settings`       | `JSON`               | `USER_INPUT`         | Filled in through a meshPanel form declared by `json_schema`, reaches Terraform as JSON text                       |
| `sensitive_text`        | `STRING` (sensitive) | `USER_INPUT`                     | Sensitive string, masked in UI and logs                                                                            |
| `single_select`         | `SINGLE_SELECT`      | `USER_INPUT`                     | One value from a predefined list                                                                                   |
| `multi_select`          | `MULTI_SELECT`       | `USER_INPUT`                     | One or more values from a predefined list                                                                          |
| `multi_select_json`     | `MULTI_SELECT`       | `USER_INPUT`                     | Same as above, as a raw JSON string                                                                                |
| `operator_text`         | `STRING`             | `PLATFORM_OPERATOR_MANUAL_INPUT` | Only a platform operator can fill this in; a block missing it parks in `WAITING_FOR_OPERATOR_INPUT`                |
| `some-file.yaml`        | `FILE`               | `STATIC`                         | Written to working directory; read via `file("some-file.yaml")`                                                    |
| `sensitive-file.yaml`   | `FILE`               | `STATIC` (sensitive)             | Like above, encrypted at rest                                                                                      |

## Output Assignment Types

| Output          | Assignment     | Description                                                            |
|-----------------|----------------|------------------------------------------------------------------------|
| `resource_url`  | `RESOURCE_URL` | Deep link to the provisioned resource, shown as an action in meshPanel |
| `summary`       | `SUMMARY`      | Markdown rendered like a readme on the block in meshPanel              |
| everything else | `NONE`         | Plain output, visible in meshPanel and consumable by other blocks      |

`RESOURCE_URL` and `SUMMARY` are the only two special output types a workspace-level block can use;
both are handled independently of `target_type`.

## What This Module Does Not Cover

meshStack's remaining input and output kinds cannot be exercised here, for two reasons:

- **Tenant-scoped.** `PLATFORM_TENANT_ID`, `MESHSTACK_TENANT_UUID`, `PROJECT_IDENTIFIER`,
  `FULL_PLATFORM_IDENTIFIER` and `TENANT_BUILDING_BLOCK_UUID` inputs, and the `SIGN_IN_URL` and
  `PLATFORM_TENANT_ID` outputs, only take effect for a `TENANT_LEVEL` building block. This one is
  `WORKSPACE_LEVEL`. See `modules/azure/resource-group` for a tenant-level example.

  Beware that a `SIGN_IN_URL` output is **silently accepted** on a workspace-level definition:
  meshStack skips its validator for this `target_type` and then discards the value, because the
  only thing it feeds is a tenant's console link and a workspace has no tenant. A test that reads
  the output back still passes, so declaring one here would look like coverage and prove nothing.
- **Needs setup beyond this module.** `BUILDING_BLOCK_OUTPUT` needs a second definition to read an
  output from, and `TAG` needs a tag definition in the instance's tag schema plus a tag value on the
  workspace.

`LIST` is deprecated in favour of `CODE`, so it is deliberately absent.

### How FILE Inputs Work

meshStack writes FILE inputs as files in the Terraform working directory before `tofu init` runs. Access them in Terraform with:

```hcl
output "some_file_yaml" {
  value = yamldecode(file("some-file.yaml"))
}
```
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.0, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [terraform_data.noop](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [external_external.aws_version](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_author"></a> [author](#input\_author) | Principal that ordered this building block, injected by the AUTHOR assignment type. | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_conditional_text"></a> [conditional\_text](#input\_conditional\_text) | n/a | `string` | `"tf-default-value"` | no |
| <a name="input_deploy_settings"></a> [deploy\_settings](#input\_deploy\_settings) | n/a | `string` | n/a | yes |
| <a name="input_flag"></a> [flag](#input\_flag) | n/a | `bool` | n/a | yes |
| <a name="input_multi_select"></a> [multi\_select](#input\_multi\_select) | n/a | `list(string)` | n/a | yes |
| <a name="input_multi_select_json"></a> [multi\_select\_json](#input\_multi\_select\_json) | n/a | `string` | n/a | yes |
| <a name="input_num"></a> [num](#input\_num) | n/a | `number` | n/a | yes |
| <a name="input_operator_text"></a> [operator\_text](#input\_operator\_text) | Value a platform operator filled in for this block. | `string` | n/a | yes |
| <a name="input_optional_text"></a> [optional\_text](#input\_optional\_text) | n/a | `string` | `"tf-default-value"` | no |
| <a name="input_sensitive_text"></a> [sensitive\_text](#input\_sensitive\_text) | n/a | `string` | n/a | yes |
| <a name="input_sensitive_yaml"></a> [sensitive\_yaml](#input\_sensitive\_yaml) | n/a | `any` | n/a | yes |
| <a name="input_single_select"></a> [single\_select](#input\_single\_select) | n/a | `string` | n/a | yes |
| <a name="input_static"></a> [static](#input\_static) | n/a | `string` | n/a | yes |
| <a name="input_static_code"></a> [static\_code](#input\_static\_code) | n/a | `map(string)` | n/a | yes |
| <a name="input_tag_value"></a> [tag\_value](#input\_tag\_value) | n/a | `list(string)` | n/a | yes |
| <a name="input_text"></a> [text](#input\_text) | n/a | `string` | n/a | yes |
| <a name="input_user_permissions"></a> [user\_permissions](#input\_user\_permissions) | n/a | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_user_permissions_json"></a> [user\_permissions\_json](#input\_user\_permissions\_json) | n/a | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier of the workspace this block belongs to, injected by meshStack. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_conditional_text"></a> [conditional\_text](#output\_conditional\_text) | n/a |
| <a name="output_author"></a> [author](#output\_author) | n/a |
| <a name="output_debug_input_files_json"></a> [debug\_input\_files\_json](#output\_debug\_input\_files\_json) | JSON-encoded map of all input files received, including sensitive values in plaintext. |
| <a name="output_debug_input_variables_json"></a> [debug\_input\_variables\_json](#output\_debug\_input\_variables\_json) | JSON-encoded map of all input variables received, including sensitive values in plaintext. |
| <a name="output_deploy_settings"></a> [deploy\_settings](#output\_deploy\_settings) | n/a |
| <a name="output_flag"></a> [flag](#output\_flag) | n/a |
| <a name="output_multi_select"></a> [multi\_select](#output\_multi\_select) | n/a |
| <a name="output_multi_select_json"></a> [multi\_select\_json](#output\_multi\_select\_json) | n/a |
| <a name="output_num"></a> [num](#output\_num) | n/a |
| <a name="output_operator_text"></a> [operator\_text](#output\_operator\_text) | n/a |
| <a name="output_optional_text"></a> [optional\_text](#output\_optional\_text) | n/a |
| <a name="output_resource_url"></a> [resource\_url](#output\_resource\_url) | n/a |
| <a name="output_sensitive_file_yaml"></a> [sensitive\_file\_yaml](#output\_sensitive\_file\_yaml) | n/a |
| <a name="output_sensitive_text"></a> [sensitive\_text](#output\_sensitive\_text) | n/a |
| <a name="output_sensitive_yaml"></a> [sensitive\_yaml](#output\_sensitive\_yaml) | n/a |
| <a name="output_single_select"></a> [single\_select](#output\_single\_select) | n/a |
| <a name="output_some_file_yaml"></a> [some\_file\_yaml](#output\_some\_file\_yaml) | n/a |
| <a name="output_static"></a> [static](#output\_static) | n/a |
| <a name="output_static_code"></a> [static\_code](#output\_static\_code) | n/a |
| <a name="output_summary"></a> [summary](#output\_summary) | n/a |
| <a name="output_tag_value"></a> [tag\_value](#output\_tag\_value) | n/a |
| <a name="output_text"></a> [text](#output\_text) | n/a |
| <a name="output_user_permissions"></a> [user\_permissions](#output\_user\_permissions) | n/a |
| <a name="output_user_permissions_json"></a> [user\_permissions\_json](#output\_user\_permissions\_json) | n/a |
| <a name="output_workspace_identifier"></a> [workspace\_identifier](#output\_workspace\_identifier) | n/a |
<!-- END_TF_DOCS -->
