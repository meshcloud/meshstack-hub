---
name: meshStack Temporary Group Access
supportedPlatforms:
  - meshstack
description: Grants a meshStack group a role on a workspace for a limited number of days, then deletes itself.
---

# meshStack Temporary Group Access

This building block binds one meshStack group, chosen by the platform team, to the workspace it is
ordered in, with a workspace role and for a number of days the orderer chooses. Typical uses are a
support or audit team that needs access to a workspace for a limited time.

## How the access ends

Two mechanisms end the access, so it never depends on one of them alone:

- The binding carries meshStack's own `expiry_date`, so meshStack stops honouring it after that
  date.
- The [backplane](../backplane/README.md) runs a sweeper once a day. It deletes every building block
  of this definition whose `expires_at` output lies in the past, and the destroy run of the deleted
  block removes the binding.

## Permissions

The run uses the ephemeral token meshStack hands it, with the `WORKSPACEPRINCIPALBINDING_*`
permissions the definition declares. It needs no API key of its own. Only the sweeper does.

## Roles with recertification or approval

- If recertification is enabled for the role, meshStack rejects an expiry date beyond its
  recertification maximum. Keep `max_duration_days` within it.
- If the role needs four-eyes approval, the binding stays `PENDING` until someone approves it in
  meshPanel, and the duration counts from the first run regardless.
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.28.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_workspace_group_binding.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/workspace_group_binding) | resource |
| [random_uuid.binding](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [time_static.created](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_workspace_identifiers"></a> [allowed\_workspace\_identifiers](#input\_allowed\_workspace\_identifiers) | Workspaces this building block may grant access to. A run in any other workspace fails before anything is bound. Empty allows every workspace. | `list(string)` | n/a | yes |
| <a name="input_duration_days"></a> [duration\_days](#input\_duration\_days) | How many days the group keeps its role on the workspace, counted from the first run of this building block. | `number` | n/a | yes |
| <a name="input_group_identifier"></a> [group\_identifier](#input\_group\_identifier) | Identifier of the meshStack group that gets the role on the workspace. Not its display name. | `string` | n/a | yes |
| <a name="input_max_duration_days"></a> [max\_duration\_days](#input\_max\_duration\_days) | Longest duration an orderer may ask for. A longer one fails the run before anything is bound. | `number` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier of the workspace the group is bound to. meshStack fills it in with the workspace the building block is ordered in. | `string` | n/a | yes |
| <a name="input_workspace_role_name"></a> [workspace\_role\_name](#input\_workspace\_role\_name) | meshStack workspace role granted to the group, e.g. `Workspace Member`. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_expires_at"></a> [expires\_at](#output\_expires\_at) | RFC 3339 timestamp after which the access ends. The sweeper of the backplane deletes this building block on its first run after it. |
| <a name="output_expiry_date"></a> [expiry\_date](#output\_expiry\_date) | Date (YYYY-MM-DD) set as the expiry date of the group binding. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
