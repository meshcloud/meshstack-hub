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
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block_v2.github_actions_dev](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.github_actions_prod](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.repo](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/building_block_v2) | resource |
| [meshstack_project.dev](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/project) | resource |
| [meshstack_project.prod](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_dev_admin](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/project_user_binding) | resource |
| [meshstack_project_user_binding.creator_prod_admin](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/project_user_binding) | resource |
| [meshstack_tenant_v4.dev](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/tenant_v4) | resource |
| [meshstack_tenant_v4.prod](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/tenant_v4) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_full_platform_identifier"></a> [full\_platform\_identifier](#input\_full\_platform\_identifier) | Full platform identifier of the AKS Namespace platform. | `string` | n/a | yes |
| <a name="input_github_actions_connector_definition_version_uuid"></a> [github\_actions\_connector\_definition\_version\_uuid](#input\_github\_actions\_connector\_definition\_version\_uuid) | UUID of the GitHub Actions connector building block definition version. | `string` | n/a | yes |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organization name. Used only for display purposes. | `string` | n/a | yes |
| <a name="input_github_repo_definition_uuid"></a> [github\_repo\_definition\_uuid](#input\_github\_repo\_definition\_uuid) | UUID of the GitHub repository building block definition. | `string` | n/a | yes |
| <a name="input_github_repo_definition_version_uuid"></a> [github\_repo\_definition\_version\_uuid](#input\_github\_repo\_definition\_version\_uuid) | UUID of the GitHub repository building block definition version. | `string` | n/a | yes |
| <a name="input_github_repo_input_repo_visibility"></a> [github\_repo\_input\_repo\_visibility](#input\_github\_repo\_input\_repo\_visibility) | Visibility of the GitHub repository (e.g., public, private). | `string` | `"private"` | no |
| <a name="input_landing_zone_dev_identifier"></a> [landing\_zone\_dev\_identifier](#input\_landing\_zone\_dev\_identifier) | AKS Landing zone identifier for the development tenant. | `string` | n/a | yes |
| <a name="input_landing_zone_prod_identifier"></a> [landing\_zone\_prod\_identifier](#input\_landing\_zone\_prod\_identifier) | AKS Landing zone identifier for the production tenant. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created projects, app subdomain and GitHub repository. | `string` | n/a | yes |
| <a name="input_project_tags_yaml"></a> [project\_tags\_yaml](#input\_project\_tags\_yaml) | YAML configuration for project tags that will be applied to dev and prod projects. Expected structure:<pre>yaml<br/>dev:<br/>  key1:<br/>    - "value1"<br/>    - "value2"<br/>  key2:<br/>    - "value3"<br/>prod:<br/>  key1:<br/>    - "value4"<br/>  key2:<br/>    - "value5"<br/>    - "value6"</pre> | `string` | `"dev: {}\nprod: {}\n"` | no |
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
