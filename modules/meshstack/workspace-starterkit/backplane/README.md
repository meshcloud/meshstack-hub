# meshStack Workspace Starterkit — Backplane

Creates the automation principal the building block authenticates with: a single admin-scoped
meshStack API key, owned by the workspace that deploys the starterkit.

## Why an admin-scoped key

The building block creates a workspace, a payment method, a project, a tenant and two role
bindings. Those are `ADM_*` operations — the payment method endpoints have no workspace-scoped
`SAVE` at all — and meshStack never grants a building block run's own ephemeral token an `ADM_*`
permission, whatever the definition declares. So the building block cannot act as itself; it acts
as this key, which the definition hands to every run as `MESHSTACK_API_KEY` and
`MESHSTACK_API_SECRET`.

The key has to outlive a single run: a per-run key would be gone before the run that tears an
expired workspace down, weeks later. See below for how long it can actually live.

The permission list is in the `permissions` local in [main.tf](main.tf), grouped so it can be read
against the resources in [../buildingblock/main.tf](../buildingblock/main.tf). If an instance needs
more than that, add them through `additional_api_key_permissions` rather than waiting on a hub
release.

## What the applying identity needs

Whoever applies this backplane authenticates the `meshstack` provider themselves — this module
configures no provider. That credential needs:

- `ADM_APIKEY_SAVE` — to create the key, and to rotate its secret when `api_key_expires_at` moves.
- `ADM_APIKEY_DELETE` — to destroy it with the backplane.

A key can only be granted permissions its creator holds, so the applying credential also needs the
`ADM_*` permissions listed in `main.tf`.

## The key expires, and that is not optional

meshStack requires an expiry on every API key and caps how far out it may sit — 90 days on the
instance this was written against. An instance may cap it lower, and answers an apply that asks for
more with a 409 naming its own maximum. There is no never-expires option to fall back on.

So this backplane has to be re-applied to stay useful. `api_key_lifetime_days` (90 by default) sets
the validity, and a `time_rotating` resource rolls the expiry forward on the first apply past half
that many days — no diff in between, so a deployment that applies at least that often never lets
the key lapse.

Past the expiry, every run of this building block fails to authenticate. That includes the runs
that destroy workspaces whose TTL has elapsed, so expired workspaces quietly stop being cleaned up
rather than failing loudly.

Each roll rotates the client secret. meshStack returns the new one, and the building block
definition picks it up on the same apply.

## Destroying it

Destroying this backplane deletes the key, which breaks every building block that still points at
it. Destroy the building blocks first.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.20.6 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_api_key.automation](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/api_key) | resource |
| [time_rotating.api_key](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_api_key_permissions"></a> [additional\_api\_key\_permissions](#input\_additional\_api\_key\_permissions) | Permissions to add to the ones the building block is known to need (see the `permissions` local in main.tf). An escape hatch for an instance whose configuration needs more — e.g. `ADM_USER_LIST` where resolving the owner's username requires it — so a deployment is not blocked on a hub release. | `list(string)` | `[]` | no |
| <a name="input_api_key_display_name"></a> [api\_key\_display\_name](#input\_api\_key\_display\_name) | Display name of the API key, as it appears in the owning workspace's API key list. Give each deployment its own name if an instance runs several flavours of this starterkit. | `string` | `"meshstack-workspace-starterkit"` | no |
| <a name="input_api_key_lifetime_days"></a> [api\_key\_lifetime\_days](#input\_api\_key\_lifetime\_days) | How long the API key is valid. meshStack requires an expiry and caps how far out it may sit, so this cannot be turned off — an instance that caps it lower than this answers the apply with a 409 naming its maximum. The expiry rolls forward on the first apply past half this many days, so a deployment applying at least that often keeps the key alive; past the expiry every run of this building block fails to authenticate, cleanup runs included. | `number` | `90` | no |
| <a name="input_meshstack_workspace_identifier"></a> [meshstack\_workspace\_identifier](#input\_meshstack\_workspace\_identifier) | Identifier of the meshStack workspace that owns the API key. The key's permissions are admin-scoped, so this decides who administers the key, not what it can reach. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_key_client_id"></a> [api\_key\_client\_id](#output\_api\_key\_client\_id) | Client id of the API key. Wire into the building block definition as the `MESHSTACK_API_KEY` environment input. |
| <a name="output_api_key_client_secret"></a> [api\_key\_client\_secret](#output\_api\_key\_client\_secret) | Client secret of the API key. Wire into the building block definition as the `MESHSTACK_API_SECRET` environment input, as a sensitive one. |
<!-- END_TF_DOCS -->
