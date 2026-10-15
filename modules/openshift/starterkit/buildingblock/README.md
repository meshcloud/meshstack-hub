---
name: OpenShift Starter Kit
supportedPlatforms:
  - openshift
description: Provisions one project with an OpenShift tenant per stage the platform offers, a GitHub repository from a template, and a GitHub Actions connector that deploys each stage into its project.
# Only orders meshStack objects with the run's own API key; the cluster-side setup belongs to the
# openshift/github-connector backplane.
requiresBackplane: false
---

# OpenShift Starter Kit

This building block creates one meshStack project per stage the platform offers, each with a
dedicated OpenShift tenant (project/namespace) in that stage's landing zone, and one GitHub
repository from a template. A `openshift/github-connector` per stage wires the repository's
GitHub environment of that stage to its namespace. The keys of `landing_zone_refs` decide the
stages. If the creator is a user identity, they are granted the Project Admin role on every project.

Each stage gets the app hostname `<name>-<stage>.<apps_domain>` (`<name>.<apps_domain>` for
`prod`), passed to its GitHub environment as `APP_HOSTNAME` for the workflow's route. `prod`
deploys from the `release` branch, every other stage from `main`.

`prerun.sh` writes one `app_link_<stage>` output per stage before the run, because an `output`
block cannot be declared per key of a map.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.8.1, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.github_actions](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.repo](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_to_admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_tenant.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_uuid.binding](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_random_name_suffix"></a> [add\_random\_name\_suffix](#input\_add\_random\_name\_suffix) | Whether to append a random suffix to the name, so the same name can be ordered more than once on a shared cluster. | `bool` | n/a | yes |
| <a name="input_apps_domain"></a> [apps\_domain](#input\_apps\_domain) | Wildcard domain of the cluster's default router, under which the app hostnames are created (example: `apps.ocp.example.com`). | `string` | n/a | yes |
| <a name="input_building_block_definition_version_refs"></a> [building\_block\_definition\_version\_refs](#input\_building\_block\_definition\_version\_refs) | Building block definition versions this starter kit creates its child building blocks from, keyed by definition name (`git-repository` and `github-actions-connector`). | <pre>map(object({<br/>    uuid = string<br/>  }))</pre> | n/a | yes |
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organization the repository is created in. Used for display only. | `string` | n/a | yes |
| <a name="input_github_template_repo_path"></a> [github\_template\_repo\_path](#input\_github\_template\_repo\_path) | Template repository the application repository is created from, as `owner/repo`. | `string` | n/a | yes |
| <a name="input_landing_zone_refs"></a> [landing\_zone\_refs](#input\_landing\_zone\_refs) | Landing zone references keyed by stage. The keys decide which stages this starter kit creates. Wired in as a static building block input from the platform/backplane that owns the meshLandingZones (their `.ref` outputs). | `map(object({ name = string, kind = optional(string, "meshLandingZone") }))` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created projects, the GitHub repository and the app hostnames. | `string` | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Reference (by uuid) to the meshPlatform the tenants are created on. Wired in as a static building block input from the platform/backplane that owns the meshPlatform (its `.ref` output). Required because the meshTenant v4 API references platforms by ref. | <pre>object({<br/>    uuid = string<br/>    kind = optional(string, "meshPlatform")<br/>  })</pre> | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags for the created meshProjects. `stages` is keyed as `landing_zone_refs`; `owner_tag_key` names the tag that receives the creator's display name. | <pre>object({<br/>    stages        = map(map(list(string)))<br/>    owner_tag_key = optional(string, null)<br/>  })</pre> | n/a | yes |
| <a name="input_repo_admin"></a> [repo\_admin](#input\_repo\_admin) | GitHub handle that becomes admin of the repository. `null` or the string `"null"` adds no one. | `string` | `null` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_repo_url"></a> [github\_repo\_url](#output\_github\_repo\_url) | URL of the created GitHub repository. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with next steps and insights into created resources. |
<!-- END_TF_DOCS -->
