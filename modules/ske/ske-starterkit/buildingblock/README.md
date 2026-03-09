---
name: SKE Starter Kit
supportedPlatforms:
  - stackit
description: Provisions a paired dev/prod project setup with SKE tenants and optional Project Admin bindings on the STACKIT Kubernetes Engine platform.
---

# SKE Starter Kit

This building block creates a dev and prod meshStack project pair, each with a dedicated SKE tenant assigned to the appropriate landing zone. If the creator is a user identity, they are granted the Project Admin role on both projects.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | ~>0.19.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_project.dev](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project.prod](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_dev_admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_project_user_binding.creator_prod_admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_tenant_v4.dev](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant_v4) | resource |
| [meshstack_tenant_v4.prod](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant_v4) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br>    type        = string<br>    identifier  = string<br>    displayName = string<br>    username    = optional(string)<br>    email       = optional(string)<br>    euid        = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_full_platform_identifier"></a> [full\_platform\_identifier](#input\_full\_platform\_identifier) | Full platform identifier of the SKE platform. | `string` | n/a | yes |
| <a name="input_landing_zone_dev_identifier"></a> [landing\_zone\_dev\_identifier](#input\_landing\_zone\_dev\_identifier) | SKE Landing zone identifier for the development tenant. | `string` | n/a | yes |
| <a name="input_landing_zone_prod_identifier"></a> [landing\_zone\_prod\_identifier](#input\_landing\_zone\_prod\_identifier) | SKE Landing zone identifier for the production tenant. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created projects. | `string` | n/a | yes |
| <a name="input_project_tags_yaml"></a> [project\_tags\_yaml](#input\_project\_tags\_yaml) | YAML configuration for project tags that will be applied to dev and prod projects. Expected structure:<pre>yaml<br>dev:<br>  key1:<br>    - "value1"<br>    - "value2"<br>  key2:<br>    - "value3"<br>prod:<br>  key1:<br>    - "value4"<br>  key2:<br>    - "value5"<br>    - "value6"</pre> | `string` | `"{\"dev\": {}, \"prod\": {}}"` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dev_project_identifier"></a> [dev\_project\_identifier](#output\_dev\_project\_identifier) | The meshStack project identifier for the dev environment. |
| <a name="output_dev_tenant_identifier"></a> [dev\_tenant\_identifier](#output\_dev\_tenant\_identifier) | The meshStack tenant identifier for the dev environment. |
| <a name="output_prod_project_identifier"></a> [prod\_project\_identifier](#output\_prod\_project\_identifier) | The meshStack project identifier for the prod environment. |
| <a name="output_prod_tenant_identifier"></a> [prod\_tenant\_identifier](#output\_prod\_tenant\_identifier) | The meshStack tenant identifier for the prod environment. |
<!-- END_TF_DOCS -->