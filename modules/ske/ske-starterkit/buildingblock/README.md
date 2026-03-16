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
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | ~>0.20.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block_v2.forgejo_connector](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.git_repository](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_v2) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_to_admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_tenant_v4.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant_v4) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_building_block_definition_version_refs"></a> [building\_block\_definition\_version\_refs](#input\_building\_block\_definition\_version\_refs) | n/a | `map(object({ uuid = string }))` | n/a | yes |
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_full_platform_identifier"></a> [full\_platform\_identifier](#input\_full\_platform\_identifier) | Full platform identifier of the SKE platform. | `string` | n/a | yes |
| <a name="input_git_repository_definition_uuid"></a> [git\_repository\_definition\_uuid](#input\_git\_repository\_definition\_uuid) | Definition UUID of the composed git-repository building block. | `string` | n/a | yes |
| <a name="input_landing_zone_identifiers"></a> [landing\_zone\_identifiers](#input\_landing\_zone\_identifiers) | SKE Landing zone identifiers for the dev/prod meshTenant. | <pre>object({<br/>    dev  = string<br/>    prod = string<br/>  })</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created projects. | `string` | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags for dev/prod meshProject. | <pre>object({<br/>    dev : map(list(string))<br/>    prod : map(list(string))<br/><br/>    owner_tag_key = optional(string, null)<br/>  })</pre> | n/a | yes |
| <a name="input_repo_clone_addr"></a> [repo\_clone\_addr](#input\_repo\_clone\_addr) | URL to clone into the starterkit git repository. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | n/a | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->