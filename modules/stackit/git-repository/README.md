# STACKIT Git Repository Module

This module wires the full meshStack integration for the STACKIT Git Repository building block.

It combines:

- `backplane/`: shared static configuration and pre-checks
- `buildingblock/`: tenant-facing repository provisioning logic
- `meshstack_integration.tf`: registration of the building block definition in meshStack

## What the meshStack integration provides

`meshstack_integration.tf` creates a `meshstack_building_block_definition` with:

- workspace-level target type
- static inputs from backplane (`FORGEJO_HOST`, `FORGEJO_API_TOKEN`, `forgejo_organization`)
- optional static sensitive action secrets (`action_secrets`)
- user inputs (`name`, `description`, `private`, `clone_addr`)
- outputs exposed to users (`repository_id`, `repository_html_url`, `repository_clone_url`, `repository_ssh_url`, `summary`)

This allows platform teams to publish a reusable self-service Git repository building block for tenants.

## Backplane behavior

The backplane ensures that `forgejo_organization` exists before building block usage:

- it calls the Forgejo org endpoint via `data "http"`, authenticated with the configured token
- if the org is missing (`status_code != 200`), it fails with a clear error message

Because the lookup call is authenticated, this also validates that the configured token is working against the target Forgejo instance.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | ~> 0.20.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_meshstack"></a> [meshstack](#provider\_meshstack) | 0.20.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_backplane"></a> [backplane](#module\_backplane) | github.com/meshcloud/meshstack-hub//modules/stackit/git-repository/backplane | a3843c80c76c4a0298769eea8d93807bb2b271fc |

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block_definition.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_action_secrets"></a> [action\_secrets](#input\_action\_secrets) | n/a | `map(string)` | `{}` | no |
| <a name="input_action_variables"></a> [action\_variables](#input\_action\_variables) | n/a | `map(string)` | `{}` | no |
| <a name="input_forgejo_base_url"></a> [forgejo\_base\_url](#input\_forgejo\_base\_url) | n/a | `string` | n/a | yes |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | n/a | `string` | n/a | yes |
| <a name="input_forgejo_token"></a> [forgejo\_token](#input\_forgejo\_token) | n/a | `string` | n/a | yes |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br><br/>`bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_meshstack"></a> [meshstack](#input\_meshstack) | n/a | <pre>object({<br/>    owning_workspace_identifier = string<br/>  })</pre> | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project ID hosting the shared Forgejo instance. Used for project role assignments. | `string` | n/a | yes |
| <a name="input_stackit_service_account_key"></a> [stackit\_service\_account\_key](#input\_stackit\_service\_account\_key) | STACKIT service account key used to authenticate the STACKIT provider in the git-repository building block. | `string` | n/a | yes |
| <a name="input_workspace_members"></a> [workspace\_members](#input\_workspace\_members) | Workspace members that should receive repository access. Populated via USER\_PERMISSIONS assignment on each building block instance. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_building_block_definition"></a> [building\_block\_definition](#output\_building\_block\_definition) | BBD is consumed in Building Block compositions, for example in the backplane of starter kits. |
<!-- END_TF_DOCS -->