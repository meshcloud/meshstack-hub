---
name: STACKIT Git Repository
supportedPlatforms:
  - stackit
description: Provisions a Git repository on STACKIT Git (Forgejo) with optional clone_addr support for one-time cloning from any public Git URL.
---

## Why `restapi` is used for Action secrets & variables

Action secrets and variables are managed by the
[`action-variables-and-secrets`](./action-variables-and-secrets/) sub-module
using the generic `restapi` provider because the Forgejo Terraform provider
currently cannot delete secrets (only removes them from state) and does not
support action variables at all. See the sub-module README for details.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | ~> 2.3.0 |
| <a name="requirement_forgejo"></a> [forgejo](#requirement\_forgejo) | ~> 1.3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.8.1 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | ~> 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_action_variables_and_secrets"></a> [action\_variables\_and\_secrets](#module\_action\_variables\_and\_secrets) | ./action-variables-and-secrets | n/a |

## Resources

| Name | Type |
|------|------|
| [forgejo_repository.this](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository) | resource |
| [forgejo_team.this](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/team) | resource |
| [random_string.team_suffix](https://registry.terraform.io/providers/hashicorp/random/3.8.1/docs/resources/string) | resource |
| [restapi_object.team_member](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.team_repo](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [external_external.env](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [forgejo_organization.this](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/data-sources/organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_action_secrets"></a> [action\_secrets](#input\_action\_secrets) | Map of Forgejo Actions secrets to create in the repository. | `map(string)` | `{}` | no |
| <a name="input_action_variables"></a> [action\_variables](#input\_action\_variables) | Map of Forgejo Actions variables to create in the repository. | `map(string)` | `{}` | no |
| <a name="input_clone_addr"></a> [clone\_addr](#input\_clone\_addr) | Optional URL to clone into this repository, e.g. 'https://github.com/owner/repo.git'. Leave empty or `null` to create an empty repository. | `string` | `"null"` | no |
| <a name="input_default_branch"></a> [default\_branch](#input\_default\_branch) | Default branch name | `string` | `"main"` | no |
| <a name="input_description"></a> [description](#input\_description) | Short description of the repository | `string` | `""` | no |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | STACKIT Git organization where the repository will be created | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the Git repository to create | `string` | n/a | yes |
| <a name="input_private"></a> [private](#input\_private) | Whether the repository should be private | `bool` | `true` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | n/a | `string` | n/a | yes |
| <a name="input_workspace_members"></a> [workspace\_members](#input\_workspace\_members) | Workspace members used for collaborator and optional STACKIT project access reconciliation. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repository_clone_url"></a> [repository\_clone\_url](#output\_repository\_clone\_url) | HTTPS clone URL |
| <a name="output_repository_html_url"></a> [repository\_html\_url](#output\_repository\_html\_url) | Web URL of the repository |
| <a name="output_repository_id"></a> [repository\_id](#output\_repository\_id) | The ID of the created repository |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Name of the created repository |
| <a name="output_repository_ssh_url"></a> [repository\_ssh\_url](#output\_repository\_ssh\_url) | SSH clone URL |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with next steps and links for the created repository |
<!-- END_TF_DOCS -->
