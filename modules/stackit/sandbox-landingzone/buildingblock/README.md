---
name: STACKIT Landing Zone
supportedPlatforms:
  - stackit
description: Onboards a STACKIT platform into meshStack by creating a location, a STACKIT resourcemanager folder and the STACKIT Project platform with its default landing zone.
---

This building block bootstraps a complete STACKIT platform integration inside a meshStack
workspace. It creates a meshStack location, a dedicated STACKIT resourcemanager folder and
sources the [`modules/stackit`](../../) project integration to provision the STACKIT Project
platform together with its default landing zone.

It authenticates to STACKIT with a service account key supplied as a secret file input; the
service account needs `resource-manager.admin` on the organization. The nested project
integration is pinned to the same `git_ref` as this building block's implementation.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.22.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.99.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_stackit_integration"></a> [stackit\_integration](#module\_stackit\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit | n/a |

## Resources

| Name | Type |
|------|------|
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [stackit_resourcemanager_folder.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_folder) | resource |
| [stackit_resourcemanager_project.backplane](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_git_ref"></a> [git\_ref](#input\_git\_ref) | meshstack-hub reference used to source the nested STACKIT project integration module. `const` so it can be interpolated into the module source at init time. | `string` | `"main"` | no |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | n/a | `string` | n/a | yes |
| <a name="input_stackit_org"></a> [stackit\_org](#input\_stackit\_org) | STACKIT organization ID under which the landing-zone folder and backplane project are created. | `string` | n/a | yes |
| <a name="input_stackit_owner_email"></a> [stackit\_owner\_email](#input\_stackit\_owner\_email) | Owner email assigned to the STACKIT resourcemanager folder and backplane project. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | <pre>object({<br/>    landingzone    = map(list(string))<br/>    building_block = map(list(string))<br/>  })</pre> | <pre>{<br/>  "building_block": {},<br/>  "landingzone": {}<br/>}</pre> | no |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that will own the created location, platform and landing zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backplane_project_id"></a> [backplane\_project\_id](#output\_backplane\_project\_id) | Project ID of the STACKIT backplane project that hosts the service account used for tenant project creation. |
| <a name="output_backplane_project_url"></a> [backplane\_project\_url](#output\_backplane\_project\_url) | Deep link to the backplane project in the STACKIT portal. |
| <a name="output_lz_folder_container_id"></a> [lz\_folder\_container\_id](#output\_lz\_folder\_container\_id) | Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder. |
<!-- END_TF_DOCS -->
