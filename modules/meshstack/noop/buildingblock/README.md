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

| Input | Type | Assignment | Description |
|-------|------|-----------|-------------|
| `user_permissions` | `CODE` | `USER_PERMISSIONS` | Project team members and their roles as a structured list |
| `user_permissions_json` | `CODE` | `USER_PERMISSIONS` | Same as above, as a raw JSON string |
| `sensitive_yaml` | `CODE` | `STATIC` (sensitive) | Encrypted YAML/JSON value, decrypted at runtime |
| `static` | `STRING` | `STATIC` | A platform-engineer-defined string constant |
| `static_code` | `CODE` | `STATIC` | A platform-engineer-defined map |
| `flag` | `BOOLEAN` | `USER_INPUT` | Boolean flag chosen by the user |
| `num` | `INTEGER` | `USER_INPUT` | Integer chosen by the user |
| `text` | `STRING` | `USER_INPUT` | Free-text string from the user |
| `sensitive_text` | `STRING` (sensitive) | `USER_INPUT` | Sensitive string, masked in UI and logs |
| `single_select` | `SINGLE_SELECT` | `USER_INPUT` | One value from a predefined list |
| `multi_select` | `MULTI_SELECT` | `USER_INPUT` | One or more values from a predefined list |
| `multi_select_json` | `MULTI_SELECT` | `USER_INPUT` | Same as above, as a raw JSON string |
| `some-file.yaml` | `FILE` | `STATIC` | Written to working directory; read via `file("some-file.yaml")` |
| `sensitive-file.yaml` | `FILE` | `STATIC` (sensitive) | Like above, encrypted at rest |

### How FILE Inputs Work

meshStack writes FILE inputs as files in the Terraform working directory before `tofu init` runs. Access them in Terraform with:

```hcl
output "some_file_yaml" {
  value = yamldecode(file("some-file.yaml"))
}
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [terraform_data.noop](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_flag"></a> [flag](#input\_flag) | n/a | `bool` | n/a | yes |
| <a name="input_multi_select"></a> [multi\_select](#input\_multi\_select) | n/a | `list(string)` | n/a | yes |
| <a name="input_multi_select_json"></a> [multi\_select\_json](#input\_multi\_select\_json) | n/a | `string` | n/a | yes |
| <a name="input_num"></a> [num](#input\_num) | n/a | `number` | n/a | yes |
| <a name="input_sensitive_text"></a> [sensitive\_text](#input\_sensitive\_text) | n/a | `string` | n/a | yes |
| <a name="input_sensitive_yaml"></a> [sensitive\_yaml](#input\_sensitive\_yaml) | n/a | `any` | n/a | yes |
| <a name="input_single_select"></a> [single\_select](#input\_single\_select) | n/a | `string` | n/a | yes |
| <a name="input_static"></a> [static](#input\_static) | n/a | `string` | n/a | yes |
| <a name="input_static_code"></a> [static\_code](#input\_static\_code) | n/a | `map(string)` | n/a | yes |
| <a name="input_text"></a> [text](#input\_text) | n/a | `string` | n/a | yes |
| <a name="input_user_permissions"></a> [user\_permissions](#input\_user\_permissions) | n/a | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_user_permissions_json"></a> [user\_permissions\_json](#input\_user\_permissions\_json) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flag"></a> [flag](#output\_flag) | n/a |
| <a name="output_multi_select"></a> [multi\_select](#output\_multi\_select) | n/a |
| <a name="output_multi_select_json"></a> [multi\_select\_json](#output\_multi\_select\_json) | n/a |
| <a name="output_num"></a> [num](#output\_num) | n/a |
| <a name="output_sensitive_file_yaml"></a> [sensitive\_file\_yaml](#output\_sensitive\_file\_yaml) | n/a |
| <a name="output_sensitive_text"></a> [sensitive\_text](#output\_sensitive\_text) | n/a |
| <a name="output_sensitive_yaml"></a> [sensitive\_yaml](#output\_sensitive\_yaml) | n/a |
| <a name="output_single_select"></a> [single\_select](#output\_single\_select) | n/a |
| <a name="output_some_file_yaml"></a> [some\_file\_yaml](#output\_some\_file\_yaml) | n/a |
| <a name="output_static"></a> [static](#output\_static) | n/a |
| <a name="output_static_code"></a> [static\_code](#output\_static\_code) | n/a |
| <a name="output_text"></a> [text](#output\_text) | n/a |
| <a name="output_user_permissions"></a> [user\_permissions](#output\_user\_permissions) | n/a |
| <a name="output_user_permissions_json"></a> [user\_permissions\_json](#output\_user\_permissions\_json) | n/a |
<!-- END_TF_DOCS -->