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
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.github_actions](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.repo](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_tenant.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_id.repo_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [meshstack_platform.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/platform) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apps_base_domain"></a> [apps\_base\_domain](#input\_apps\_base\_domain) | Base domain used for application URLs (e.g. 'likvid-k8s.msh.host'). The app subdomain will be prefixed to this value. | `string` | `"likvid-k8s.msh.host"` | no |
| <a name="input_archive_repo_on_destroy"></a> [archive\_repo\_on\_destroy](#input\_archive\_repo\_on\_destroy) | Whether to archive github repository when destroying the terraform resource, or delete it. Defaults to true (archive). | `bool` | `true` | no |
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_github_actions_connector_definition_version_uuid"></a> [github\_actions\_connector\_definition\_version\_uuid](#input\_github\_actions\_connector\_definition\_version\_uuid) | UUID of the GitHub Actions connector building block definition version. | `string` | n/a | yes |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organization name. Used only for display purposes. | `string` | n/a | yes |
| <a name="input_github_repo_definition_uuid"></a> [github\_repo\_definition\_uuid](#input\_github\_repo\_definition\_uuid) | UUID of the GitHub repository building block definition. | `string` | n/a | yes |
| <a name="input_github_repo_definition_version_uuid"></a> [github\_repo\_definition\_version\_uuid](#input\_github\_repo\_definition\_version\_uuid) | UUID of the GitHub repository building block definition version. | `string` | n/a | yes |
| <a name="input_github_repo_input_repo_visibility"></a> [github\_repo\_input\_repo\_visibility](#input\_github\_repo\_input\_repo\_visibility) | Visibility of the GitHub repository (e.g., public, private). | `string` | `"private"` | no |
| <a name="input_github_template_repo_path"></a> [github\_template\_repo\_path](#input\_github\_template\_repo\_path) | GitHub repository template to use when creating the application repository, in the format 'owner/repo'. | `string` | `"likvid-bank/aks-starterkit-template"` | no |
| <a name="input_landing_zone_refs"></a> [landing\_zone\_refs](#input\_landing\_zone\_refs) | Landing zone references keyed by stage (usually dev and prod). Wired in as a static building block input from the platform/backplane that owns the meshLandingZones (their `.ref` outputs). | `map(object({ name = string, kind = optional(string, "meshLandingZone") }))` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created projects, app subdomain and GitHub repository. | `string` | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Reference (by uuid) to the meshPlatform the tenants are created on. Wired in as a static building block input from the platform/backplane that owns the meshPlatform (its `.ref` output). Required because the meshTenant v4 API references platforms by ref. | <pre>object({<br/>    uuid = string<br/>    kind = optional(string, "meshPlatform")<br/>  })</pre> | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags for the created Dev/Prod projects. | <pre>object({<br/>    dev  = map(list(string))<br/>    prod = map(list(string))<br/><br/>    owner_tag_key = optional(string, null)<br/>  })</pre> | n/a | yes |
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
