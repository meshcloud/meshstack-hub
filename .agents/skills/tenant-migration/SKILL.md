---
name: tenant-migration
description: >
  Move meshTenants to a different meshPlatform without destroying the cloud resources behind them, by
  adopting each resource into the new building block's Terraform state. Use when asked to migrate,
  consolidate or retire meshTenants, especially off a custom platform whose landing zones carry
  mandatory building block definitions — the case where meshStack rejects a create carrying
  `spec.localId` with `CustomPlatformImportUnsupportedException` and Terraform reports
  `spec.platform_ref` as `RequiresReplace`. Covers tenant classes, the per-tenant runbook, building
  block state doctoring, access parity, Terraform state reconciliation, and retiring the emptied
  platform.
---

# Tenant Migration Skill

Moving a meshTenant from one meshPlatform to another looks like an import and is not one. meshStack
refuses the import when the target platform is `CUSTOM` and its landing zone carries a mandatory
building block definition. Terraform cannot do it either: `spec.platform_ref` is `RequiresReplace`,
replacing a meshTenant destroys its building block, and that block's teardown destroys the live cloud
resource.

The way through is **adoption**. Create the new meshTenant plainly, with no `platform_tenant_id`, so
meshStack sees an ordinary create and provisions the mandatory building block itself. Then write the
link to the existing cloud resource into the new block's **Terraform state**, before its runner starts.
The block adopts the resource instead of creating a replacement.

---

## Two rules that prevent the expensive mistakes

- **Never let Terraform replace a meshTenant.** Replacing it destroys its building block and with it
  the live cloud resource. A plan that shows a meshTenant being replaced or destroyed means stop and
  re-read the state.
- **Never delete a cloud resource in place.** Move it to the organization root first. On STACKIT a
  deleted project sits in `DELETING` for weeks and permanently blocks its parent folder's deletion.

---

## Workflow

1. **Inventory the tenants and classify each one.** The class decides the procedure — see *Classify the
   tenants*. Listing tenants needs a per-workspace filter and the right media type; both are in
   `.agents/references/meshstack-api-cookbook.md`.
2. **Build the adopt harness and prove it on a throwaway resource.** The harness is a copy of the *new*
   module's `buildingblock/` with a local state file, into which the live cloud resource is imported.
   See `.agents/references/building-block-state-doctoring.md`.
3. **Order the tenants cheapest first** — the one nothing depends on — so the procedure is exercised
   before it meets the tenant that matters.
4. **Run the per-tenant loop**, one tenant at a time, checking the run before starting the next.
5. **Reconcile Terraform state** for every tenant held in some repository's state, before anyone re-plans
   that repository. See `.agents/references/tenant-migration-runbook.md` § *Tenants held in Terraform
   state*.
6. **Retire the old platform** once no tenants remain on it — see *Retiring the old platform*.

---

## Classify the tenants

Tenants that look alike migrate differently, so establish the class before planning any work.

| Class | How to spot it | What changes |
|---|---|---|
| **Building-block-backed** | A block instance exists for the tenant on the old mandatory BBD | Purge the block before deleting the tenant, or the teardown destroys the cloud resource |
| **Replicator-created** | No block instance; the resource predates the BBD | No block to purge; the seed state must be built from the live resource |
| **Never replicated** | `spec.localId` / `platformTenantId` is null | Nothing to migrate — delete the tenant |
| **Held in IaC** | A `meshstack_tenant` resource in some repository's state points at it | Needs state reconciliation on top of the migration, or the next plan replaces the tenant |

The last class is the dangerous one, because the damage arrives later, out of a plan someone else runs.

---

## The per-tenant loop

`$MT` is a meshStack bearer token; the cookbook shows how to mint one. Steps 3 and 4 are a single
scripted unit — the runner may start on its own between them.

1. **Purge the old building block.** Skip for a tenant that has no block.

   ```sh
   curl -sS -X DELETE -H "Authorization: Bearer $MT" \
     "$MESHSTACK/api/meshobjects/meshbuildingblocks/$OLD_BB_UUID/purge"
   ```

   The answer is `202`. Within about ten seconds the block reads `forcePurge = true` and
   `lifecycle.state = DELETED`, and no destroy run happens. Confirm `forcePurge` before step 2 — the
   purge is what makes the delete safe.

2. **Delete the old meshTenant.** Also `202`, and also non-destructive *once the block is purged*.
   Without the purge, this runs the block's teardown and destroys the cloud resource.

3. **Create the new meshTenant with no `platform_tenant_id`.** Setting it is what makes meshStack treat
   the adoption as an import. Left unset, `spec.localId` stays null, the guard returns early, and
   meshStack creates the mandatory building block itself.

4. **Seed the new block's state before its runner starts.** Find the new block by diffing the uuid list
   of the mandatory BBD's blocks against the list taken before step 3, then push the seed:

   ```sh
   # block_uuids: a JSON array of the uuids under meshbuildingblocks?definitionUuid=$BBD_UUID
   before=$(block_uuids)                                    # taken before step 3
   new=$(block_uuids | jq -r --argjson b "$before" '. - $b | .[0] // empty')
   curl -sS -X POST -H "Authorization: Bearer $MT" --data-binary @seed.tfstate \
     "$MESHSTACK/api/terraform/state/workspace/$WS/buildingBlock/$new"
   ```

   Poll for `$new` with a `sleep` in the loop. Both known ways of losing the race are lookup bugs, not
   timing — see the runbook § *The race*.

5. **Let the run finish and check what it did.** Expect one in-place update on the cloud resource and no
   create of the resource itself. Creates of role assignments are normal, and getting that set wrong in
   either direction fails the run — see the runbook § *Access parity*. Read the new tenant's
   `platform_tenant_id` back: a run that fails before its output-collection step leaves it unset, which
   breaks every downstream consumer of that attribute.

---

## Risk method

These four habits are what keep the procedure recoverable. They generalise past this migration.

**Experiment on throwaway resources, and snapshot even then.** The throwaway proves the mechanism; the
snapshot is what allows a retry after the first attempt teaches something. Before mutating an object
through an API, `GET` it and keep the response — that file is the rollback. Before deleting an
attribute, record its value in the comment above the destructive command, so the restore command is
written down next to it.

**Assert on the plan, not on the intention.** Refuse to emit a seed or continue a run unless the plan
shows no destroys and no replacements. Put the check in the script, not in the operator's head:

```sh
tofu plan -out=tfplan
tofu show -json tfplan \
  | jq -e '[.resource_changes[]?.change.actions[]] | index("delete") == null' > /dev/null \
  || { echo "plan destroys or replaces a resource — refusing to proceed"; exit 1; }
```

A replacement appears as `["delete","create"]` or `["create","delete"]`, so a single check for `delete`
covers both. Then pass the expected cloud resource id into every script and abort when the resource
found does not match it.

**Prefer an operation the provider models as an in-place update** over one it models as a replacement,
and confirm which it is by planning rather than by reading documentation.

**Weigh the blast radius, not the wording of the action.** Deleting a landing zone reads as more
destructive than editing a platform's availability, but the landing zone delete is a reversible
deactivation, while the availability change is guarded by rules that can leave the platform in a state
it cannot return from. Check what each operation does before ranking them.

---

## Retiring the old platform

Do this only once no tenants remain on it.

**Deactivating its landing zones is the effective retirement.** A meshTenant cannot exist without a
landing zone, so a deactivated landing zone makes the platform unorderable whatever its availability
says. `DELETE /api/meshobjects/meshlandingzones/<identifier>` is a disable rather than a removal: the
object stays readable with `lifecycle.state = DEACTIVATED` and existing tenants are untouched. The
identifier is global, not scoped per platform, so verify uniqueness before deleting by bare identifier.

**Do not expect to unpublish the platform.** Once a platform has been published, `UNPUBLISHED` is
unreachable — the cookbook lists the three `400` guards that establish this. Deleting the platform
permanently consumes its identifier even though the delete is soft, so keep the row unless the
identifier is certainly never wanted again.

---

## Telling live code from dead code

A `kit/`-style directory that no repository references may still be live, because a building block
definition reaches it by Git repository path rather than by a module source. Grepping the repository
cannot answer the question. Ask the instance instead, and read **versions**, not definitions: a
definition's source moves over its lifetime, so the current version may point somewhere entirely
different from the version an old block is pinned to. The cookbook § *Auditing where building block code
actually lives* has the two endpoints.

---

## Key references

| Topic | Reference |
|---|---|
| Per-tenant procedure, seed construction, traps, recovery, IaC reconciliation | `.agents/references/tenant-migration-runbook.md` |
| Reaching and rewriting a running block's Terraform state; the adopt harness | `.agents/references/building-block-state-doctoring.md` |
| Endpoints, media types, validation rules, traps that read as empty results | `.agents/references/meshstack-api-cookbook.md` |
| Worked migration of nine tenants, including both failures | `.agents/references/tenant-migration-case-study.md` |
| STACKIT backplane identity | `.agents/references/stackit-backplane.md` |
