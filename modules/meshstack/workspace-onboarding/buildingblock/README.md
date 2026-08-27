---
name: meshStack Workspace Onboarding
supportedPlatforms:
  - meshstack
description: Creates a new meshStack workspace with a self-tracked TTL, a payment method, a project with a tenant, and the initial workspace and project role bindings.
requiresBackplane: false
---

# meshStack Workspace Onboarding

This building block onboards a new meshStack workspace in one order: a workspace tagged with a
self-computed expiry date (under a configurable tag key), a payment method, a project with a tenant
on any already-registered meshPlatform, and the initial workspace and project role bindings.

## Admin-scoped API key

Creating a workspace or a payment method needs meshStack `ADM_*` permissions, which a building
block's own ephemeral token never has. This module authenticates instead with
`meshstack_admin_api_key` / `meshstack_admin_api_secret` — an admin credential the platform team
sets once in `meshstack_integration.tf` — so it declares no `permissions` in `version_spec`.

## Self-destructs after its TTL

You set `workspace_ttl_days`, not a date. The block tracks its own creation time
(`time_static.created` in `main.tf`) and computes the expiry itself. Once that many days have
passed, the next run destroys everything it created — workspace, payment method, project, tenant,
both bindings. The block itself is not self-purging: it stays behind so its outputs still show what
happened.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_payment_method.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/payment_method) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project_user_binding.admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_tenant.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [meshstack_workspace.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/workspace) | resource |
| [meshstack_workspace_user_binding.owner](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/workspace_user_binding) | resource |
| [time_static.created](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_landing_zone_ref"></a> [landing\_zone\_ref](#input\_landing\_zone\_ref) | Reference to the landing zone the tenant is placed in. | <pre>object({<br/>    name = string<br/>    kind = string<br/>  })</pre> | n/a | yes |
| <a name="input_meshstack_admin_api_key"></a> [meshstack\_admin\_api\_key](#input\_meshstack\_admin\_api\_key) | Admin-scoped meshStack API key. Creating a workspace and a payment method needs ADM\_* permissions meshStack never grants to a building block's own ephemeral run token, so every meshStack resource here is authenticated with this key/secret pair instead. | `string` | n/a | yes |
| <a name="input_meshstack_admin_api_secret"></a> [meshstack\_admin\_api\_secret](#input\_meshstack\_admin\_api\_secret) | Admin-scoped meshStack API secret, paired with meshstack\_admin\_api\_key. | `string` | n/a | yes |
| <a name="input_payment_method_amount"></a> [payment\_method\_amount](#input\_payment\_method\_amount) | Budget amount for the payment method. | `number` | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Reference (by uuid) to the meshPlatform the tenant is created on. | <pre>object({<br/>    uuid = string<br/>    kind = string<br/>  })</pre> | n/a | yes |
| <a name="input_project_display_name"></a> [project\_display\_name](#input\_project\_display\_name) | Display name for the project. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | Identifier for the project created inside the new workspace. | `string` | n/a | yes |
| <a name="input_project_role_name"></a> [project\_role\_name](#input\_project\_role\_name) | meshStack project role granted to `workspace_owner_username`. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged onto the workspace (alongside the mandatory `expiry` tag), the payment method and the project. | <pre>object({<br/>    workspace      = map(list(string))<br/>    payment_method = map(list(string))<br/>    project        = map(list(string))<br/>  })</pre> | n/a | yes |
| <a name="input_workspace_display_name"></a> [workspace\_display\_name](#input\_workspace\_display\_name) | Display name for the new workspace. | `string` | n/a | yes |
| <a name="input_workspace_expiry_tag_key"></a> [workspace\_expiry\_tag\_key](#input\_workspace\_expiry\_tag\_key) | Tag key the computed expiry date is written under on the new workspace. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier for the new meshStack workspace. | `string` | n/a | yes |
| <a name="input_workspace_owner_username"></a> [workspace\_owner\_username](#input\_workspace\_owner\_username) | Username granted `workspace_role_name` on the new workspace and `project_role_name` on the new project — one owner for both. | `string` | n/a | yes |
| <a name="input_workspace_role_name"></a> [workspace\_role\_name](#input\_workspace\_role\_name) | meshStack workspace role granted to `workspace_owner_username`. | `string` | n/a | yes |
| <a name="input_workspace_ttl_days"></a> [workspace\_ttl\_days](#input\_workspace\_ttl\_days) | Number of days after this building block first creates the workspace before it, the payment method, the project and the tenant are destroyed. The module tracks the creation date itself (see time\_static.created in main.tf) — this input is a duration, not a date. | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_payment_method_identifier"></a> [payment\_method\_identifier](#output\_payment\_method\_identifier) | Identifier of the payment method — of the one that existed, if the run destroyed it because the workspace's expiry date had passed. |
| <a name="output_project_identifier"></a> [project\_identifier](#output\_project\_identifier) | Identifier of the project — of the one that existed, if the run destroyed it because the workspace's TTL had elapsed. |
| <a name="output_workspace_expiry_date"></a> [workspace\_expiry\_date](#output\_workspace\_expiry\_date) | Date (YYYY-MM-DD) this building block computed from its creation date plus workspace\_ttl\_days — the date the workspace, and everything else this block created, are destroyed on the next run. |
| <a name="output_workspace_identifier"></a> [workspace\_identifier](#output\_workspace\_identifier) | Identifier of the workspace — of the one that existed, if the run destroyed it because its expiry date had passed. |
<!-- END_TF_DOCS -->
