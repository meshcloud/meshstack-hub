---
name: tenant-migration
description: >
  Move meshTenants between meshPlatforms without destroying the cloud resources behind them. Use when
  asked to migrate, consolidate or retire tenants on a custom platform whose landing zones carry
  mandatory building block definitions — the case where meshStack's own import path is refused. Covers
  inventory, the per-tenant runbook, building block state doctoring, Terraform state reconciliation,
  retiring the old platform, and the traps that fail a run.
---

# Tenant Migration Skill

Moving a meshTenant from one meshPlatform to another looks like an import and is not one. On a custom
platform whose landing zone carries a mandatory building block definition, meshStack refuses the import
outright, and Terraform cannot do it either because `spec.platform_ref` is `RequiresReplace` — replacing
a meshTenant destroys its building block, and the building block's teardown destroys the live cloud
resource.

The way through is to create the new tenant plainly and make the link to the existing cloud resource in
**Terraform state** instead of through the meshStack API. The building block then adopts the resource
rather than creating a replacement.

Read these references before starting:

- `.agents/references/tenant-migration-runbook.md` — the per-tenant procedure and its ordering
- `.agents/references/building-block-state-doctoring.md` — reaching and rewriting a block's state
- `.agents/references/meshstack-api-cookbook.md` — endpoints, media types and the traps
- `.agents/references/tenant-migration-case-study.md` — a worked migration of nine tenants

---

## Two rules that prevent the expensive mistakes

- **Never let Terraform replace a meshTenant.** Replacing it destroys its building block and with it the
  live cloud resource. If a plan shows a tenant being replaced or destroyed, stop and re-read the state.
- **Never delete a cloud resource in place.** Move it to the organization root first. On STACKIT a
  deleted project sits in `DELETING` for weeks and blocks its parent folder's deletion permanently.

## Method

1. **Inventory first, and classify.** Tenants that look alike migrate differently. See *Classify the
   tenants* below.
2. **Prove the procedure on a throwaway resource** before touching anything real, and snapshot whatever
   you are about to mutate so you can put it back.
3. **Assert on the plan, not on your intention.** Refuse to proceed unless the plan shows zero destroys
   and no replacements. Automate that check so it cannot be skipped when you are tired.
4. **Interlock on identity.** Pass the expected cloud resource id into every script and abort when what
   you find does not match.
5. **Migrate the cheapest tenant first** — the one nothing depends on — so the procedure is exercised
   before it meets the tenant that matters.

## Classify the tenants

The class decides the procedure, so establish it before planning any work:

| Class | How to spot it | What changes |
|---|---|---|
| **Building-block-backed** | A block instance exists for the tenant on the old mandatory BBD | Purge the block before deleting the tenant, or the teardown destroys the cloud resource |
| **Replicator-created** | No block instance; the resource predates the BBD | No block to purge; the seed state must be built from the live resource |
| **Never replicated** | `spec.localId` / `platformTenantId` is null | Nothing to migrate — delete the tenant |
| **Held in IaC** | A `meshstack_tenant` resource in some repo's state points at it | Needs state reconciliation on top of the migration, or the next plan replaces it |

The last class is the dangerous one, because the damage arrives later, from a plan someone else runs.

## Risk method

**Experiment on throwaway resources, but snapshot even then.** A throwaway proves the mechanism; the
snapshot is what lets you retry after the first attempt teaches you something. Concretely:

- Before mutating an object through an API, `GET` it and keep the response. That file is your rollback.
- Before deleting an attribute, record its value in the command's own comment, so the restore command is
  written down next to the destructive one.
- Prefer an operation the provider models as an in-place update over one it models as a replacement, and
  confirm which it is by planning rather than by reading documentation.

**Weigh the blast radius, not the action.** Deleting a landing zone reads as more destructive than
editing a platform's availability, but the landing zone delete is a reversible deactivation while the
availability change is guarded by rules that can leave the platform in a state you cannot return from.
Check what each operation actually does before ranking them.

## Retiring the old platform

Do this only once no tenants remain on it.

**Deactivating its landing zones is the effective retirement.** A meshTenant cannot exist without a
landing zone, so a deactivated landing zone makes the platform unorderable whatever its availability
says. `DELETE /api/meshobjects/meshlandingzones/<identifier>` is a disable, not a removal: the object
stays readable with `lifecycle.state = DEACTIVATED` and existing tenants are untouched.

**Do not expect to unpublish the platform.** Once a platform has been published, `UNPUBLISHED` is
unreachable — see the cookbook. And deleting the platform burns its identifier permanently even though
the delete is soft, so keep the row unless you are certain the identifier is never wanted again.

## Telling live code from dead code

A `kit/`-style directory that no repository references may still be live, because a building block
definition reaches it by Git repository path rather than by a module source. Grepping the repository
cannot answer the question. Ask the instance instead, and check **versions**, not definitions: a
definition's source moves over its lifetime, so the current version may point somewhere entirely
different from the version an old block is pinned to. See the cookbook for the two endpoints.
