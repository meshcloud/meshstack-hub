---
name: AKS Starterkit
supportedPlatforms:
  - aks
description: |
  The AKS Starterkit provides application teams with a pre-configured Kubernetes environment. It includes two Kubernetes namespaces (dev&prod), a Git repository, a CI/CD pipeline using GitHub Actions, and a secure container registry integration.
---

# AKS Starterkit Building Block

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.github_actions](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.namespace](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.repo](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [random_id.repo_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apps_base_domain"></a> [apps\_base\_domain](#input\_apps\_base\_domain) | Base domain used for application URLs (e.g. 'likvid-k8s.msh.host'). The app subdomain will be prefixed to this value. | `string` | `"likvid-k8s.msh.host"` | no |
| <a name="input_archive_repo_on_destroy"></a> [archive\_repo\_on\_destroy](#input\_archive\_repo\_on\_destroy) | Whether to archive github repository when destroying the terraform resource, or delete it. Defaults to true (archive). | `bool` | `true` | no |
| <a name="input_building_block_definition_version_refs"></a> [building\_block\_definition\_version\_refs](#input\_building\_block\_definition\_version\_refs) | Building block definition versions this starter kit creates its child building blocks from, keyed by definition name (`git-repository`, `aks-namespace` and `github-actions-connector`). | <pre>map(object({<br/>    uuid = string<br/>  }))</pre> | n/a | yes |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organization name. Used only for display purposes. | `string` | n/a | yes |
| <a name="input_github_repo_input_repo_visibility"></a> [github\_repo\_input\_repo\_visibility](#input\_github\_repo\_input\_repo\_visibility) | Visibility of the GitHub repository (e.g., public, private). | `string` | `"private"` | no |
| <a name="input_github_template_repo_path"></a> [github\_template\_repo\_path](#input\_github\_template\_repo\_path) | GitHub repository template to use when creating the application repository, in the format 'owner/repo'. | `string` | `"likvid-bank/aks-starterkit-template"` | no |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created namespaces, app subdomain and GitHub repository. | `string` | n/a | yes |
| <a name="input_namespace_group_object_ids"></a> [namespace\_group\_object\_ids](#input\_namespace\_group\_object\_ids) | Existing Entra group object IDs granted the admin, edit and view role in every created namespace, in addition to the groups each namespace creates for its workspace members. | <pre>object({<br/>    admin = optional(list(string), [])<br/>    edit  = optional(list(string), [])<br/>    view  = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_repo_admin"></a> [repo\_admin](#input\_repo\_admin) | GitHub handle of the user who will be assigned as the repository admin. Delete building block definition input if not needed. | `string` | `null` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dev-link"></a> [dev-link](#output\_dev-link) | Link to the dev environment Angular app |
| <a name="output_github_repo_url"></a> [github\_repo\_url](#output\_github\_repo\_url) | URL of the created GitHub repository |
| <a name="output_prod-link"></a> [prod-link](#output\_prod-link) | Link to the prod environment Angular app |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with next steps and insights into created resources |
<!-- END_TF_DOCS -->
