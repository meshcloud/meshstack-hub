# Case study: migrating nine tenants off a custom STACKIT platform

A worked example, kept because the failures are more instructive than the procedure. Nine meshTenants moved
from a hand-built custom platform (`stackit.sovereign`, owned by one workspace) to a platform deployed by
the STACKIT landing zone reference architecture (`likvid-stackit.global`), on a demo meshStack instance.

Outcome: seven tenants migrated with their cloud project ids intact, two deleted as never-replicated, all
seven building blocks `SUCCEEDED`, all seven projects moved into the new platform's folder, no duplicate
project created at any point.

## The inventory, and why the classes mattered

| Class | Count | Procedure difference |
|---|---|---|
| Building-block-backed | 4 | Purge the old block before deleting the tenant |
| Replicator-created | 3 | No block to purge; seed had to be built from the live project |
| Never replicated | 2 | Deleted — `platformTenantId` was null, nothing to migrate |
| Also held in Terraform | 2 (subset of the above) | Needed `state rm` + `import` reconciliation afterwards |

The four building-block-backed projects were exactly the four sitting at the organization root, because the
old BBD set `parent_container_id` to the organization. The three in folders predated the block and were made
by the replicator. That correlation was the fastest way to classify them.

Ordering mattered: the three replicator-created tenants went first because nothing depended on them, which
meant the procedure was exercised twice before it met the project running a live Kubernetes cluster.

## Failure 1: pre-existing role assignments

The first migration failed on the apply with:

```
Error: Error while checking for duplicate role assignments
found a duplicate role assignment
```

The seed carried the project but no role assignments, so Terraform tried to create all six grants the
meshProject called for. Two already existed, put there by the old replicator. The duplicate error failed
the **whole apply**, so the project was renamed and moved but no grants were created and the run never
reached its output-collection step.

The fix looked obvious — put every existing grant in the seed — and was wrong in the other direction. A
grant in the seed that the run's configuration does not contain gets **destroyed**. On the project hosting
the Kubernetes cluster that would have stripped `owner` from the cluster's own service accounts.

So the set has to be computed: read the meshProject's user bindings, map them through the BBD's
`role_mapping`, and adopt only the intersection with what exists in the cloud. Service accounts and legacy
roles fall outside that set and stay unmanaged. On one project this left an out-of-band `reader` grant
untouched, which is the correct outcome — the block never asked to manage it.

Reading the bindings needed the non-obvious endpoint, because `meshusers` is 403 without a `USER_*`
permission. The role-name mapping (`Project Admin → admin`, `Project User → user`,
`Project Reader → reader`) was confirmed against a real run's `users` input rather than assumed.

## Failure 2: labels the provider cannot clear

The second migration failed differently:

```
Error: Provider produced inconsistent result after apply
… .labels: was null, but now cty.MapVal(map[string]cty.Value{"project":…, "workspace":…})
```

The hub module computes `labels = length(var.labels) > 0 ? var.labels : null` and the BBD passes `{}`, so
every adoption plans `labels -> null`. STACKIT ignores that instead of clearing the labels, and the
provider then fails the apply. Two of the three replicator-created projects carried the replicator's own
`project` / `workspace` labels and hit it.

Clearing the labels fixed those two. The third project was worse: it carried `billingReference=""`, and

```
DELETE /v2/projects/<id>/labels?keys=billingReference
→ 409 The label [billingReference] is protected and can't be changed or deleted
```

even for the organization owner. `stackit project update --label` can only add labels, and a `PATCH` with
`labels: {}` is a merge that silently keeps everything. What works is an explicit null:

```sh
curl -X PATCH -H "Authorization: Bearer $(stackit auth get-access-token)" \
  -H 'Content-Type: application/json' -d '{"labels":{"billingReference":null}}' \
  "https://resource-manager.api.stackit.cloud/v2/projects/<id>"
```

Three things this taught, in order of usefulness:

**Lying in the seed does not work.** Recording `labels: null` in the pushed state looks like it should
suppress the diff, but the runner refreshes before it plans, and the refresh puts reality back.

**A failed first run has a consequence beyond the red status.** The apply dies before the
output-collection step, so the new meshTenant never gets a `platform_tenant_id`. Anything reading that
attribute downstream — in this case a `stackit_project_id` output feeding four other units — would have
broken. That is why this tenant could not simply be pushed through with a known-failing block.

**Diagnose the origin before assuming a configuration bug.** The label was not set by any repository:
`billingReference` appeared nowhere in the foundation, the hub or the sibling foundation, and all 44
projects belonging to the other foundation's install had no labels at all. The old building block did not
set it either — its `labels` input was `{}`, the same as sibling projects that came out clean, and it
created the project 21 seconds after itself with no labels. A scan of all 107 projects in the organization
found the key on exactly two, both the same platform project and its predecessor, both updated a month
after creation. It was a manual Portal edit, and STACKIT exposes the field as a first-class *Billing
Reference* project setting whose storage happens to be a protected label. The Portal renders "absent" and
"present but empty" identically, so the UI cannot distinguish the broken state from the healthy one.

## What went right, and why

**The adopt harness.** After the first failure, seed construction moved from rewriting the old block's
state to importing the live project into a byte-identical copy of the new module and planning it. That
turned every subsequent migration into a reviewed change: the harness printed the plan and refused to emit
a seed unless it showed no replacements and no destroys. Every later run came back
`0 added, 1 changed, 0 destroyed`, and the one change was computed timestamps.

**The race was never lost** across seven migrations. The documented fifteen-second window against a
sub-second script is a wide enough margin that the timing is not the risk; the lookup logic is.

**Container moves are genuinely in-place.** Terraform planned `parent_container_id` as an update, the
project id survived, and the meshTenant's `platform_tenant_id` — which *is* the project id — stayed valid.
`owner_email` is create-only in STACKIT, so the provider recorded the new value while the actual owner did
not change; that is a silent state-versus-reality divergence worth knowing about but harmless here.

**Adoption avoided a permanent mess.** STACKIT deletions sit in `DELETING` for weeks — observed at 21 and
134 days on this organization — and block the parent folder's deletion with a `409`. Creating replacements
and deleting the originals would have left seven tombstones inside the new platform's folder, making it
undeletable for good. Adopting sidesteps the problem instead of paying for it seven times.

## Retiring the old platform

Once empty, the intent was to unpublish it. That is impossible: `UNPUBLISHED` requires
`restriction = PRIVATE`, and `PRIVATE` is permanently forbidden once a platform has been published. The
three `400` messages that establish this are in the cookbook.

What worked instead was deactivating its three landing zones and deleting the old mandatory BBD. Since a
meshTenant cannot exist without a landing zone, that makes the platform unorderable regardless of its
availability. The platform row was deliberately left `ACTIVE`: deleting it burns the identifier
permanently, and it was still the `SUCCESSFUL` metering comparison against the new platform's `FAILED`
metering — a useful control while that question was open.

## Two corrections the migration forced on the plan

Both were assumptions that had been written down as facts, and both were caught only by reading the live
instance:

- A landing zone the plan claimed existed did not, because the deployment never set the input that creates
  it. That changed a downstream design decision (a select would show one option, not two).
- The claim that platform availability "cannot be set in code at all" was wrong. The API accepts it; the
  hub module's `ignore_changes` on it is a convention, not a limitation.

The lesson is narrow and worth stating: in migration work, verify the current state against the API before
planning around it, especially for anything a document asserts about a deployed system.
