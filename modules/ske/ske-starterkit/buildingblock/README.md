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
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.8.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.forgejo_connector](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.git_repository](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_to_admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_tenant.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_uuid.binding](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_random_name_suffix"></a> [add\_random\_name\_suffix](#input\_add\_random\_name\_suffix) | Whether to append a random suffix to the provided name for shared environments. | `bool` | n/a | yes |
| <a name="input_building_block_definitions"></a> [building\_block\_definitions](#input\_building\_block\_definitions) | n/a | <pre>map(object({<br/>    uuid = string<br/>    version_ref = object({<br/>      uuid = string<br/>    })<br/>  }))</pre> | n/a | yes |
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_dns_zone_name"></a> [dns\_zone\_name](#input\_dns\_zone\_name) | DNS zone name used for application ingress hostnames. | `string` | n/a | yes |
| <a name="input_landing_zone_refs"></a> [landing\_zone\_refs](#input\_landing\_zone\_refs) | Landing zone references keyed by stage (usually dev and prod). Wired in as a static building block input from the platform/backplane that owns the meshLandingZones (their `.ref` outputs). | `map(object({ name = string, kind = optional(string, "meshLandingZone") }))` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created projects. | `string` | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Reference (by uuid) to the meshPlatform the tenants are created on. Wired in as a static building block input from the platform/backplane that owns the meshPlatform (its `.ref` output). Required because the meshTenant v4 API references platforms by ref. | <pre>object({<br/>    uuid = string<br/>    kind = optional(string, "meshPlatform")<br/>  })</pre> | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags for dev/prod meshProject. | <pre>object({<br/>    dev : map(list(string))<br/>    prod : map(list(string))<br/><br/>    owner_tag_key = optional(string, null)<br/>  })</pre> | n/a | yes |
| <a name="input_repo_clone_addr"></a> [repo\_clone\_addr](#input\_repo\_clone\_addr) | URL to clone into the starterkit git repository. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_link_dev"></a> [app\_link\_dev](#output\_app\_link\_dev) | Public URL for the dev stage application. |
| <a name="output_app_link_prod"></a> [app\_link\_prod](#output\_app\_link\_prod) | Public URL for the prod stage application. |
<!-- END_TF_DOCS -->