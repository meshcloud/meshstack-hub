# Tenant migration tooling

The scripts that ran the STACKIT migration this skill is written from: they move a meshTenant from one
meshPlatform to another **without destroying the cloud resource behind it**. Seven tenants were migrated
with them, off `stackit.sovereign` onto `likvid-stackit.global`.

Read [the runbook](../../../references/tenant-migration-runbook.md) first. It carries the reasoning;
this file only covers how to run the scripts.

**They are a worked example, not a general tool.** The migration logic is portable, but the platform
and role details are STACKIT-specific: the `adopt/` harness is a copy of the STACKIT project starterkit,
and `role_mapping` maps meshStack project roles onto STACKIT `owner` / `editor` / `reader`. For another
platform, keep the shape and replace those parts.

| File | Purpose |
|---|---|
| `env.sh` | Credentials and API constants. Source it, do not execute it. |
| `adopt-seed.sh` | Builds the seed state from the **live** cloud resource. Preferred. |
| `migrate.sh` | Migrates one tenant end to end. |
| `reseed.jq` | Rewrites an old block's Terraform state into the new module's resource shape. Superseded by `adopt-seed.sh`. |
| `adopt/` | Standalone plan harness — a byte-identical copy of the hub module the runner executes. |

## Configure the instance first

Nothing is hardcoded to an instance, and nothing has a default — the wrong value here migrates the
wrong tenants:

```sh
export MIG_IAC_REPO=~/git/likvid-bank/likvid-cloudfoundation   # its setup-env.sh loads the API key
export MIG_MESH_URL=https://federation.<instance>.meshcloud.io
export MIG_CLIENT_ID=<meshstack api key client id>
export MIG_PARENT_CONTAINER_ID=<landing-zone folder container id>
export MIG_SERVICE_ACCOUNT_EMAIL=<platform service account>
export MIG_NEW_BBD_UUID=<target landing zone's mandatory building block definition>
```

`env.sh` derives the SSO host from `MIG_MESH_URL` by swapping `federation.` for `sso.`; set
`MIG_SSO_URL` if your instance does not follow that pattern.

## Running one migration

Two steps. Build the seed, then migrate:

```sh
source scripts/env.sh
scripts/adopt-seed.sh <workspace> <project> <container-id> <cloud-project-id>
scripts/migrate.sh    <workspace> <project> - <cloud-project-id>
```

`adopt-seed.sh` imports the live project and its adoptable role assignments, prints the plan, and writes
`/tmp/mig-seed.json`. It aborts unless the plan adds and destroys nothing on the project itself —
creates of role assignments are expected and fine. `migrate.sh` sources `env.sh` itself; `-` as its
third argument means "the seed is already prepared".

This works whether or not the tenant has an old building block. When it has one, purge it first and
confirm the purge before letting `migrate.sh` delete the tenant:

```sh
curl -X DELETE -H "Authorization: Bearer $MT" -H "$BBACC" \
  "$MESH/api/meshobjects/meshbuildingblocks/<old-bb-uuid>/purge"
```

The older single-step form still works and uses `reseed.jq` instead, purging the old block itself:

```sh
scripts/migrate.sh <workspace> <project> <old-bb-uuid> <cloud-project-id>
```

Prefer `adopt-seed.sh`. It reads reality instead of trusting the old state, and it catches the two
things that fail a run: a pre-existing role assignment missing from the seed, and a project label the
module wants to clear. Both are in the runbook, under *Access parity* and *Labels can block the
adoption outright*.

The project-id argument is a safety interlock, not a convenience: both scripts abort if what they find
holds a different project id than the one given.

## Check the labels first

```sh
stackit project describe <project-id> -o json | jq .labels
```

Anything non-empty fails the run, because the module plans `labels -> null` and STACKIT does not clear
them. Remove them with an explicit null — `stackit project update --label` can only add, and the
`DELETE .../labels` endpoint refuses protected keys such as `billingReference` with a 409:

```sh
curl -X PATCH -H "Authorization: Bearer $(stackit auth get-access-token)" \
  -H 'Content-Type: application/json' -d '{"labels":{"<key>":null}}' \
  "https://resource-manager.api.stackit.cloud/v2/projects/<project-id>"
```

This is a provider bug, reported upstream on
[stackitcloud/terraform-provider-stackit#1381](https://github.com/stackitcloud/terraform-provider-stackit/issues/1381)
and still open as of `0.112.0`. `labels` is `Optional` and not `Computed`, so a configuration that omits
it plans `labels -> null`, STACKIT does not clear them, and the apply fails on the inconsistent result.
For a protected label such as `billingReference` there is no workaround through the labels endpoint at
all — only the `PATCH` above.

## What it does

1. Reads the old block's state and verifies the project id.
2. Purges the old building block — `DELETE .../purge`, which runs **no destroy** and leaves the
   cloud project intact.
3. Deletes the old meshTenant.
4. Creates the new meshTenant with **no** `platform_tenant_id`. Setting it would make meshStack treat
   the adoption as an import, which custom platforms reject.
5. Seeds the new block's state before its runner starts, then waits for the run.

## The race

Between steps 4 and 5 the runner may start on its own — the window is roughly fifteen seconds. If it
wins, it creates a *duplicate* cloud project. Recovery is known and lossless; see *The race* in the
runbook. The one rule that matters: **move a doomed project to the organization root before deleting
it**, because STACKIT deletions sit in `DELETING` for weeks and block the parent folder.

The race was never lost across the seven migrations. Every failure was a plan problem instead, and those
are recoverable too — purge the new block, delete the new tenant, fix the seed, re-run. See *Recovery
when the first run fails* in the runbook, including how to read a run's log, which needs one specific
`Accept` header and 406s on everything else.

## If nothing comes back

An expired Vault session produces a 401, and `jq` renders that as an empty list — so "no tenants
found" usually means "not authenticated". `env.sh` checks for this and fails loudly. To fix it, run
`source ./setup-env.sh` in a real terminal so the interactive OIDC login can complete.
