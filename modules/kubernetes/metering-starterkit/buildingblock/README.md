---
name: Platform Metering
supportedPlatforms:
  - kubernetes
description: Sets up custom metering for the clouds a platform team selects, in one Kubernetes namespace with one metering CronJob per cloud.
# A composition of other building blocks that authenticates with the run's ephemeral meshStack API
# key, so there is nothing to set up cloud-side beforehand.
requiresBackplane: false
---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.27.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [meshstack_building_block.metering](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.service_account](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_tenant.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_clouds"></a> [clouds](#input\_clouds) | Clouds whose costs are metered, keys of `metering_building_block_definition_version_refs`. | `list(string)` | n/a | yes |
| <a name="input_landing_zone_ref"></a> [landing\_zone\_ref](#input\_landing\_zone\_ref) | Landing zone of the metering namespace. | <pre>object({<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_metering_building_block_definition_version_refs"></a> [metering\_building\_block\_definition\_version\_refs](#input\_metering\_building\_block\_definition\_version\_refs) | Versions of the metering definitions, keyed by the cloud name offered in `clouds`. | <pre>map(object({<br/>    uuid = string<br/>  }))</pre> | n/a | yes |
| <a name="input_payment_method"></a> [payment\_method](#input\_payment\_method) | Payment method of the metering project. | <pre>object({<br/>    kind = string<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Kubernetes meshPlatform the metering namespace is created on. | <pre>object({<br/>    uuid = string<br/>  })</pre> | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the metering project, and so part of its namespace. | `string` | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags of the metering project. | `map(list(string))` | n/a | yes |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Cron schedule of every metering job. | `string` | n/a | yes |
| <a name="input_service_account_definition_version_ref"></a> [service\_account\_definition\_version\_ref](#input\_service\_account\_definition\_version\_ref) | Version of the Kubernetes Service Account definition the metering deploys with. | <pre>object({<br/>    uuid = string<br/>  })</pre> | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Workspace that gets the metering project. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
