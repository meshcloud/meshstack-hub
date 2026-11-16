# meshStack Temporary Group Access — Backplane

meshStack has no timer that deletes a building block, so this backplane provides one: a **sweeper**
that runs once a day and deletes every expired building block of the access definition. It is
built from meshStack parts only, so there is no cron job, function or cluster to operate:

- `meshstack_api_key.sweeper`: an admin-scoped API key, owned by the platform team's workspace.
- `meshstack_building_block_definition.sweeper`: a `WORKSPACE_LEVEL` definition running
  [`sweeper/`](sweeper/main.tf) on a daily `DRIFT_RECONCILIATION` schedule with automatic approval.
- `meshstack_building_block.sweeper`: the one instance of it, in the platform team's workspace.

Each daily run lists the access blocks with `meshstack_building_blocks`, picks those whose
`expires_at` output has passed, and deletes them through the meshStack API
([`delete-building-block.sh`](sweeper/delete-building-block.sh)). The destroy run of a deleted
access block removes its group binding. The sweeper's run summary lists what it deleted.

## Why an admin-scoped key

The access blocks live in every workspace that ordered one, and a run's ephemeral token only
reaches its own workspace. The key holds exactly two permissions:

| Permission | Why |
|---|---|
| `MANAGED_BUILDINGBLOCK_LIST` | List the blocks of the access definition across workspaces |
| `ADM_BUILDINGBLOCK_DELETE` | Delete them. meshStack has no `MANAGED_` scope for deleting a building block |

## What the applying identity needs

This module configures no provider. The credential that applies it needs `ADM_APIKEY_SAVE` and
`ADM_APIKEY_DELETE`, the two permissions above (a key cannot be granted more than its creator
holds), and the permissions to save building block definitions and building blocks in the owning
workspace.

## The key expires

meshStack requires an expiry on every API key and caps how far out it may sit. `time_rotating` rolls
the expiry forward on the first apply past half of `api_key_lifetime_days`, so re-apply at least that
often. Past the expiry, the sweeper fails to authenticate and expired access blocks stay. Their
group bindings still end on their `expiry_date`, which meshStack enforces itself.

## Runner requirements

The sweeper takes `curl` and `jq` from the flake in [`sweeper/nix`](sweeper/nix/flake.nix), so the
runner needs `nix`.

## Destroying it

Destroying the backplane deletes the sweeper and its key. Expired access blocks are then no longer
deleted automatically.
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
