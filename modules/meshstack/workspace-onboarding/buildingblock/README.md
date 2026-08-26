---
name: meshStack Workspace Onboarding
supportedPlatforms:
  - stackit
description: Creates a new meshStack workspace with a configurable expiry tag, a payment method, a project with a STACKIT tenant, and the initial workspace and project role bindings.
# Only calls the meshStack API against an already-registered STACKIT platform/landing zone; provisions nothing cloud-side of its own.
requiresBackplane: false
---

# meshStack Workspace Onboarding

This building block onboards a new meshStack workspace in one order: a workspace tagged with an
expiry date (under a configurable tag key), a payment method, a project with a STACKIT tenant, and
the initial workspace and project role bindings.

## Admin-scoped API key

Creating a workspace or a payment method requires meshStack `ADM_*` permissions, which meshStack
only grants to users in the Admin Area — never to the ephemeral, workspace-scoped API token a
running building block gets. This module works around that by authenticating every resource it
manages through an aliased `meshstack` provider (see `provider.tf`), configured with an admin-scoped
API key/secret pair injected as `STATIC` sensitive inputs (`meshstack_admin_api_key` /
`meshstack_admin_api_secret`) in `meshstack_integration.tf`. The platform team supplies that
credential once, when deploying this definition — it is never exposed to whoever orders the
building block.

Because the whole block is driven by that admin credential rather than its own ephemeral one, it
declares no `permissions` in `version_spec`.

## Self-destructs after expiry

Every resource is gated behind `lifecycle { enabled = !local.expired }` in `main.tf`, where
`local.expired` compares `plantimestamp()` against `workspace_expiry_date` (the same date written to
the workspace's expiry tag, under the key `workspace_expiry_tag_key` names). Ordering a run of this
building block after that date has passed therefore destroys the workspace, payment method, project
and STACKIT tenant it created — bindings and the tenant first, then the project and payment method,
then the workspace, in the normal destroy order OpenTofu derives from the resource references.
`plantimestamp()`, not `timestamp()`, because `lifecycle.enabled` must be known at plan time and
`timestamp()` is deliberately unknown until apply.

This is not a self-purging building block like `stackit-project-starterkit`: the block itself stays
around after its resources are gone, with a `summary` output explaining what happened, so an operator
can see why the workspace disappeared. Push `workspace_expiry_date` out (it is
`updateable_by_consumer`) before it passes to keep a workspace alive.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |

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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_landing_zone_ref"></a> [landing\_zone\_ref](#input\_landing\_zone\_ref) | Reference to the landing zone the tenant is placed in. | <pre>object({<br/>    name = string<br/>    kind = string<br/>  })</pre> | n/a | yes |
| <a name="input_meshstack_admin_api_key"></a> [meshstack\_admin\_api\_key](#input\_meshstack\_admin\_api\_key) | Admin-scoped meshStack API key. Creating a workspace and a payment method needs ADM\_* permissions meshStack never grants to a building block's own ephemeral run token, so every resource here is managed through an aliased provider authenticated with this key/secret pair instead. | `string` | n/a | yes |
| <a name="input_meshstack_admin_api_secret"></a> [meshstack\_admin\_api\_secret](#input\_meshstack\_admin\_api\_secret) | Admin-scoped meshStack API secret, paired with meshstack\_admin\_api\_key. | `string` | n/a | yes |
| <a name="input_payment_method_amount"></a> [payment\_method\_amount](#input\_payment\_method\_amount) | Budget amount for the payment method. | `number` | n/a | yes |
| <a name="input_payment_method_expiration_date"></a> [payment\_method\_expiration\_date](#input\_payment\_method\_expiration\_date) | Expiration date (YYYY-MM-DD) of the payment method itself, independent of the workspace's `expiry` tag. Empty string means no expiration. | `string` | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Reference (by uuid) to the STACKIT meshPlatform the tenant is created on. | <pre>object({<br/>    uuid = string<br/>    kind = string<br/>  })</pre> | n/a | yes |
| <a name="input_project_admin_username"></a> [project\_admin\_username](#input\_project\_admin\_username) | Username granted `project_role_name` on the new project. | `string` | n/a | yes |
| <a name="input_project_display_name"></a> [project\_display\_name](#input\_project\_display\_name) | Display name for the project. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | Identifier for the project created inside the new workspace. | `string` | n/a | yes |
| <a name="input_project_role_name"></a> [project\_role\_name](#input\_project\_role\_name) | meshStack project role granted to `project_admin_username`. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged onto the workspace (alongside the mandatory `expiry` tag), the payment method and the project. | <pre>object({<br/>    workspace      = map(list(string))<br/>    payment_method = map(list(string))<br/>    project        = map(list(string))<br/>  })</pre> | n/a | yes |
| <a name="input_workspace_display_name"></a> [workspace\_display\_name](#input\_workspace\_display\_name) | Display name for the new workspace. | `string` | n/a | yes |
| <a name="input_workspace_expiry_date"></a> [workspace\_expiry\_date](#input\_workspace\_expiry\_date) | Expiry date (YYYY-MM-DD) written to the workspace's `workspace_expiry_tag_key` tag. | `string` | n/a | yes |
| <a name="input_workspace_expiry_tag_key"></a> [workspace\_expiry\_tag\_key](#input\_workspace\_expiry\_tag\_key) | Tag key `workspace_expiry_date` is written under on the new workspace. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier for the new meshStack workspace. | `string` | n/a | yes |
| <a name="input_workspace_owner_username"></a> [workspace\_owner\_username](#input\_workspace\_owner\_username) | Username granted `workspace_role_name` on the new workspace. | `string` | n/a | yes |
| <a name="input_workspace_role_name"></a> [workspace\_role\_name](#input\_workspace\_role\_name) | meshStack workspace role granted to `workspace_owner_username`. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_payment_method_identifier"></a> [payment\_method\_identifier](#output\_payment\_method\_identifier) | Identifier of the payment method — of the one that existed, if the run destroyed it because the workspace's expiry date had passed. |
| <a name="output_project_identifier"></a> [project\_identifier](#output\_project\_identifier) | Identifier of the project — of the one that existed, if the run destroyed it because the workspace's expiry date had passed. |
| <a name="output_stackit_project_url"></a> [stackit\_project\_url](#output\_stackit\_project\_url) | Deep link to the STACKIT project, once the tenant has replicated. Reports the expiry once the workspace's expiry date has passed and everything has been destroyed. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of what this building block created, or of the fact that it destroyed everything because the workspace's expiry date passed. |
| <a name="output_workspace_identifier"></a> [workspace\_identifier](#output\_workspace\_identifier) | Identifier of the workspace — of the one that existed, if the run destroyed it because its expiry date had passed. |
<!-- END_TF_DOCS -->
