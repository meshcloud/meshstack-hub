---
name: meshStack Workspace Starterkit
supportedPlatforms:
  - meshstack
description: Creates a new meshStack workspace with a self-tracked TTL, a payment method, a project with a tenant, and the initial workspace and project role bindings.
---

# meshStack Workspace Starterkit

This building block onboards a new meshStack workspace in one order: a workspace tagged with a
self-computed expiry date (under a configurable tag key), a payment method, a project with a tenant
on any already-registered meshPlatform, and the initial workspace and project role bindings.

## Admin-scoped API key

Creating a workspace or a payment method needs `ADM_*` permissions, which a building block's own
ephemeral token never has — so this module declares no `permissions` and authenticates as the API
key [the backplane](../backplane/README.md) mints. That key arrives as the `MESHSTACK_API_KEY` /
`MESHSTACK_API_SECRET` environment inputs, so the provider configures itself and the credential is
not a module input at all.

## What the instance has to have first

Both of these surface as a `409 TagValidation` from the workspace the run tried to create:

- **The expiry tag key must exist in the tag schema**, configured for workspaces.
  `workspace_expiry_tag_key` defaults to `expiry`; an instance without that tag definition answers
  `You cannot add the following tags [expiry]`.
- **Mandatory tags must be supplied** through `var.meshstack.tags.*`, which are merged onto what
  this block creates. A missing one answers `Mandatory tag(s) ... must be provided`.

## Self-destructs after its TTL

You set `workspace_ttl_days`, not a date. The block tracks its own creation time and computes the
expiry itself. Once that many days have passed, the next run destroys everything it created. The
block itself stays behind, so its outputs still show what happened.

Left unset, expiry tracking is off: no expiry tag, no expiration on the payment method or the owner
binding, and no run that tears anything down. The creation time is still recorded, so setting a TTL
later still counts from the workspace's real creation date.

## Several flavours from one module

The definition's display name, description and readme, the **Workspace TTL (Days)** and **Payment
Method Amount** defaults, and the identifier validation regexes are variables of
`meshstack_integration.tf`. Deploy the module once per flavour — a long-lived team workspace next
to a time-boxed university workspace on a small budget — and give each its own name and defaults,
or the panel shows definitions an orderer cannot tell apart.

Two of those variables are less obvious:

- `workspace_ttl_days_default = null` makes the TTL input optional instead of prefilling it, so an
  orderer can choose a workspace that never expires. meshStack accepts a default or an optional
  input, never both. Needs meshStack 2026.36.0 or later.
- `workspace_identifier_pattern` defaults to the widest form meshStack accepts, 63 characters,
  while instances cap workspace identifiers at 16. Narrow it together with
  `workspace_identifier_error_message`, so an orderer reads the real rule instead of having the
  order rejected after submission.
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11.0, < 1.0.0 |

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
| <a name="input_landing_zone_ref"></a> [landing\_zone\_ref](#input\_landing\_zone\_ref) | Reference to the landing zone the tenant is placed in. | <pre>object({<br/>    name = string<br/>    kind = optional(string, "meshLandingZone")<br/>  })</pre> | n/a | yes |
| <a name="input_payment_method_amount"></a> [payment\_method\_amount](#input\_payment\_method\_amount) | Budget amount for the payment method. | `number` | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Reference (by uuid) to the meshPlatform the tenant is created on. | <pre>object({<br/>    uuid = string<br/>    kind = optional(string, "meshPlatform")<br/>  })</pre> | n/a | yes |
| <a name="input_project_display_name"></a> [project\_display\_name](#input\_project\_display\_name) | Display name for the project. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | Identifier for the project created inside the new workspace. | `string` | n/a | yes |
| <a name="input_project_role_name"></a> [project\_role\_name](#input\_project\_role\_name) | meshStack project role granted to `workspace_owner_username`. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged onto the workspace (alongside the expiry tag, if `workspace_ttl_days` is set), the payment method and the project. | <pre>object({<br/>    workspace      = map(list(string))<br/>    payment_method = map(list(string))<br/>    project        = map(list(string))<br/>  })</pre> | n/a | yes |
| <a name="input_workspace_display_name"></a> [workspace\_display\_name](#input\_workspace\_display\_name) | Display name for the new workspace. | `string` | n/a | yes |
| <a name="input_workspace_expiry_tag_key"></a> [workspace\_expiry\_tag\_key](#input\_workspace\_expiry\_tag\_key) | Tag key the computed expiry date is written under on the new workspace. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier for the new meshStack workspace. | `string` | n/a | yes |
| <a name="input_workspace_owner_username"></a> [workspace\_owner\_username](#input\_workspace\_owner\_username) | Username granted `workspace_role_name` on the new workspace and `project_role_name` on the new project — one owner for both. | `string` | n/a | yes |
| <a name="input_workspace_role_name"></a> [workspace\_role\_name](#input\_workspace\_role\_name) | meshStack workspace role granted to `workspace_owner_username`. | `string` | n/a | yes |
| <a name="input_workspace_ttl_days"></a> [workspace\_ttl\_days](#input\_workspace\_ttl\_days) | Number of days after this building block first creates the workspace before it, the payment method, the project and the tenant are destroyed. The module tracks the creation date itself (see time\_static.created in main.tf) — this input is a duration, not a date. Leave it unset to switch expiry tracking off: the workspace, payment method and owner binding then get no expiry date and nothing is ever torn down. | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_payment_method_identifier"></a> [payment\_method\_identifier](#output\_payment\_method\_identifier) | Identifier of the payment method — of the one that existed, if the run destroyed it because the workspace's expiry date had passed. |
| <a name="output_project_identifier"></a> [project\_identifier](#output\_project\_identifier) | Identifier of the project — of the one that existed, if the run destroyed it because the workspace's TTL had elapsed. |
| <a name="output_workspace_expiry_date"></a> [workspace\_expiry\_date](#output\_workspace\_expiry\_date) | Date (YYYY-MM-DD) this building block computed from its creation date plus workspace\_ttl\_days — the date the workspace, and everything else this block created, are destroyed on the next run. Null when workspace\_ttl\_days is unset and nothing expires. |
| <a name="output_workspace_identifier"></a> [workspace\_identifier](#output\_workspace\_identifier) | Identifier of the workspace — of the one that existed, if the run destroyed it because its expiry date had passed. |
<!-- END_TF_DOCS -->
