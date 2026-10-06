# STACKIT Git Repository Module

This module wires the full meshStack integration for the STACKIT Git Repository building block.

It combines:

- `buildingblock/`: tenant-facing repository provisioning logic
- `meshstack_integration.tf`: registration of the building block definition in meshStack

## What the meshStack integration provides

`meshstack_integration.tf` creates a `meshstack_building_block_definition` with:

- workspace-level target type
- static inputs `FORGEJO_HOST`, `forgejo_organization`, `default_branch` and `action_variables`
- the sensitive static input `vault_reader` and the Vault paths `forgejo_api_token_path` and, if
  set, `registry_push_path`
- user inputs (`name`, `description`, `private`, `clone_addr`, `extra_action_variables`)
- outputs exposed to users (`repository_id`, `repository_html_url`, `repository_clone_url`, `repository_ssh_url`, `summary`)

This allows platform teams to publish a reusable self-service Git repository building block for tenants.

## Secrets

The definition holds no secret value except the Vault login. Each run reads the Forgejo API token
and the optional registry push robot from a Vault KV v2 engine, such as a STACKIT Secrets Manager
instance, and sets the push robot on the repository as the Actions secrets `HARBOR_USERNAME` and
`HARBOR_PASSWORD`. What a run reads is kept in its Terraform state.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.25.2 |

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block_definition.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_action_variables"></a> [action\_variables](#input\_action\_variables) | n/a | `map(string)` | `{}` | no |
| <a name="input_approval_policies"></a> [approval\_policies](#input\_approval\_policies) | Run triggers that need an operator's approval before a run of this definition is applied. A gate switched on in meshPanel is reset on the next apply unless it is set here. | <pre>object({<br/>    building_block_creation = optional(bool, false)<br/>    user_input_changes      = optional(bool, false)<br/>    any_input_changes       = optional(bool, false)<br/>    manual_triggers         = optional(bool, false)<br/>    version_upgrade         = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_bbd_description"></a> [bbd\_description](#input\_bbd\_description) | Overrides the one-line description shown next to the marketplace entry. | `string` | `null` | no |
| <a name="input_bbd_display_name"></a> [bbd\_display\_name](#input\_bbd\_display\_name) | Overrides the name of the marketplace entry application teams see in the catalog. | `string` | `null` | no |
| <a name="input_bbd_readme"></a> [bbd\_readme](#input\_bbd\_readme) | Overrides the markdown readme shown in the marketplace before ordering. | `string` | `null` | no |
| <a name="input_forgejo_api_token_path"></a> [forgejo\_api\_token\_path](#input\_forgejo\_api\_token\_path) | Vault KV v2 secret holding the Forgejo API token under the key `forgejo_api_token`. The token needs the write:repository and write:organization scopes. | `string` | n/a | yes |
| <a name="input_forgejo_base_url"></a> [forgejo\_base\_url](#input\_forgejo\_base\_url) | n/a | `string` | n/a | yes |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | n/a | `string` | n/a | yes |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br><br/>`bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_meshstack"></a> [meshstack](#input\_meshstack) | Shared meshStack context. Tags are optional and propagated to building block definition metadata. | <pre>object({<br/>    owning_workspace_identifier = string<br/>    tags                        = optional(map(list(string)), {})<br/>  })</pre> | n/a | yes |
| <a name="input_registry_push_path"></a> [registry\_push\_path](#input\_registry\_push\_path) | Vault KV v2 secret holding a container registry push robot under the keys `username` and `password`, set on every repository as the Actions secrets `HARBOR_USERNAME` and `HARBOR_PASSWORD`. Null sets neither. | `string` | `null` | no |
| <a name="input_stackit_git_instance_id"></a> [stackit\_git\_instance\_id](#input\_stackit\_git\_instance\_id) | STACKIT Git instance whose users are matched to workspace members by email. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project of the Git instance. | `string` | n/a | yes |
| <a name="input_stackit_service_account_email"></a> [stackit\_service\_account\_email](#input\_stackit\_service\_account\_email) | Service account the runs act as via WIF to list STACKIT Git users. It must federate this definition. | `string` | n/a | yes |
| <a name="input_vault_reader"></a> [vault\_reader](#input\_vault\_reader) | Vault KV v2 login the building blocks read their secrets with: the server `address`, the engine `mount` and a userpass `username` and `password`. | <pre>object({<br/>    address  = string<br/>    mount    = string<br/>    username = string<br/>    password = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_building_block_definition"></a> [building\_block\_definition](#output\_building\_block\_definition) | BBD is consumed in building block compositions. |
<!-- END_TF_DOCS -->
