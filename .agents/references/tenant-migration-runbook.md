# Tenant migration runbook

The per-tenant procedure for moving a meshTenant to another meshPlatform while the cloud resource behind
it stays where it is and keeps its id.

## Why import is not an option

Three separate blockers, and each one is worth knowing because each rules out a different shortcut.

**meshStack refuses the import.** `MeshTenantService.verifyNoImportIntoCustomPlatformImplementedUsingBuildingBlocks`
treats `meshTenant.localId != null` on create as an import and throws `CustomPlatformImportUnsupportedException`
when the platform's category is `CUSTOM` and the landing zone has mandatory building block definitions.
The guard's own comment names the problem: the building block that is supposed to create the tenant would
have to run the equivalent of a `terraform import` to construct its initial state. That is exactly what
this runbook does — by hand, outside meshStack, where the guard cannot see it.

**A mandatory BBD with a required input blocks tenant creation entirely.** An earlier guard,
`verifyMandatoryBuildingBlocksCreatableOrThrow`, rejects a mandatory BBD carrying an input with neither
an automatic assignment nor a default: `requires Building Blocks that cannot be created due to missing
inputs: <BBD>:<input>`. A BBD whose inputs are all `STATIC`, `PROJECT_IDENTIFIER` or `USER_PERMISSIONS`
passes, which is what lets step 3 create a tenant through the plain API with no inputs at all.

**Identifiers cannot be reproduced.** `metadata.name` *is* the identifier, so renaming an object is a
replace. Importing an old landing zone under a new name only makes the next plan destroy and recreate it.

## The procedure

Steps 3 and 4 are one scripted unit, not two manual ones — see *The race*.

1. **Disarm the old building block.**
   `DELETE <meshstack>/api/meshobjects/meshbuildingblocks/<uuid>/purge` answers `202`, and within about
   ten seconds the block reads `forcePurge = true` and `lifecycle.state = DELETED`. No destroy runs and
   the cloud resource is untouched. Confirm `forcePurge` before going on — this is what makes step 2 safe.
   Skip this step for a tenant that has no block.

2. **Delete the old meshTenant.** Also `202`, and also non-destructive *once the block is purged*. Without
   the purge, this runs the block's teardown and destroys the cloud resource.

3. **Create the new meshTenant with no `platform_tenant_id`.** Setting it is what makes meshStack call the
   adoption an import. Leave it unset, `localId` stays null, and the guard returns early. meshStack then
   creates the mandatory building block itself.

4. **Seed the new block's state before its runner starts.** `POST` the prepared state to the block's state
   address. See `building-block-state-doctoring.md`.

5. **Let the run finish and check what it did.** One in-place update on the cloud resource, no creates of
   the resource itself. Creates of role assignments are normal — see below.

## Building the seed state

Two sources, and the second is better.

**From the old block's state**, when the tenant has one: `GET` the old block's state and rewrite it into
the new module's resource shape. This works when the two modules' resource addresses agree, which they
usually do if both come from the same hub module lineage. Watch for renamed resources — a `for_each`
resource renamed between module versions needs its instances re-keyed and `each: "map"` set.

**From the live cloud resource**, which is more robust and works for every class: stand up a throwaway
directory containing a copy of the *new* module's `buildingblock/`, `tofu import` the real resource into
it, plan, and use the resulting state as the seed. This reads reality instead of trusting an old state,
and the plan doubles as the safety check. Copy the buildingblock directory **with its non-`.tf` files** —
a missing `SUMMARY.md.tftpl` breaks the plan.

Whichever source, normalise before pushing:

- **`terraform_version` must not exceed the runner's.** OpenTofu refuses to read a state written by a
  newer version. Read the runner's version off a successful run's state and rewrite the field to match.
- **`serial`** to 1 and **`outputs`** to `{}` — the run recomputes them.
- Drop resource entries with no instances.

## Access parity: the trap that fails whole runs

The seed's role assignments are the ones Terraform adopts. Get the set wrong in either direction and it
costs you:

- **Too few** — a grant the run wants but the seed lacks comes back as a duplicate error from the cloud
  API, and that fails the **entire apply**, not just that grant.
- **Too many** — a grant in the seed that the run's configuration does not contain is **destroyed**,
  silently removing somebody's access. On a platform project this can strip the service accounts that
  operate the platform.

So compute the set rather than guessing it: read the meshProject's user bindings, map them through the
BBD's `role_mapping` input, and adopt only the intersection with what already exists in the cloud.
Everything else — service accounts, legacy roles, grants held by people who are not project members —
stays unmanaged and therefore untouched.

## The race

Between creating the tenant and pushing the state, the runner may start on its own. Measured window:
`PENDING` to `IN_PROGRESS` in about fifteen seconds, against a script that needs under half a second. The
margin is wide, so the race is only lost when the script fails to *find* the new block at all.

Two ways to lose it, both from the lookup rather than the timing:

- **A `jq` filter that rebinds `.`.** `select(($b|split(" "))|index(.)|not)` pipes `.` into the split
  array, so the filter never matches. Use `[uuids] - $b | .[0] // empty`, and unit-test it against both a
  hit and a miss before running it live.
- **A polling loop with no `sleep`.** Two hundred back-to-back requests finish long before meshStack has
  created the block.

**Recovery when the race is lost.** The run creates a second cloud resource and saves its own state over
your push. Nothing is destroyed and the original resource is untouched:

1. Let the run finish. Purging mid-apply just leaves the duplicate unowned.
2. Read the duplicate's id from the block's `status.outputs`, then purge the block and delete the tenant.
3. **Move the duplicate to the organization root before deleting it.** Deleting it in place leaves a
   tombstone inside the target folder that never clears and blocks that folder's deletion for good.
4. Rebuild the seed and re-run. The old tenant is already gone, so skip the disarm step.

## Recovery when the first run fails

More common than losing the race, and equally recoverable. A failed apply still saves its state and the
cloud resource keeps its id.

1. **Read the run log.** The run's `_links.downloadLogs` needs one specific `Accept` value and returns
   406 for everything else, including `*/*`. See the cookbook.
2. Fix the cause. It is almost always the access-parity set or a label.
3. Purge the new block, then delete the new tenant. Confirm `forcePurge` before deleting.
4. Rebuild the seed and re-run the migration unchanged. Its delete of the old tenant is then a harmless
   `404`, because that tenant is already gone.

There is no way to re-trigger a failed run in place: the block exposes only `forcePurge`, `meshtenant`
and `self`, and a `runs` sub-resource does not exist. Purge and re-create is the only path.

## Labels can block the adoption outright

If the module computes `labels = length(var.labels) > 0 ? var.labels : null` and the BBD passes `{}`, then
every adoption of a resource that already has labels plans `labels -> null`. When the cloud provider
ignores that instead of clearing them, the provider fails the apply:

```
Error: Provider produced inconsistent result after apply
… .labels: was null, but now cty.MapVal(map[string]cty.Value{…})
```

Check the resource's labels before adopting it. Clearing them is usually enough. A **protected** label is
worse: the dedicated label-delete endpoint refuses it, and only an explicit `null` in the update payload
removes it. Lying about labels in the seed does not work, because the runner refreshes before it plans and
the refresh puts reality back.

## Tenants held in Terraform state need reconciliation

When some repository holds the tenant as a `meshstack_tenant` resource, the out-of-band migration leaves
that state stale, and the next plan will try to fix it by replacing the tenant. Per tenant, in this order:

1. Run the migration, so the new tenant and its adopted block exist.
2. `state rm` the old tenant address, then `import` the new tenant **at the same address**. The import id
   is the tenant uuid, or the legacy `workspace.project.platform.location` composite.
3. Only now change `platform_ref` and `landing_zone_ref` in the configuration.
4. Re-plan. It must come back clean. **Anything showing a replace means stop.**

Doing step 3 before step 2 is what produces the replace. And check what reads the tenant's
`platform_tenant_id`: adoption preserves it, so those consumers keep resolving, but confirm by reading the
output back rather than assuming.
