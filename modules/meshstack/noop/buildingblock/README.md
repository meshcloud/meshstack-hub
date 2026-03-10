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