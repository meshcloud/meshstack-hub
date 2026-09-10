---
description: Conventions for meshStack provider resources in meshstack-hub — point every *_ref attribute at the target's ref output, ignore changes to meshstack_platform availability, and assert the run status of every child meshstack_building_block a starterkit or composition orders.
---

# meshStack Provider Resources

These rules hold wherever meshStack resources are declared: `meshstack_integration.tf`, a
starterkit's `buildingblock/`, or a `reference-architectures/` module.

<!-- scorecard-checks: meshstack_ref_output -->
## Referencing meshStack Objects

Point every `*_ref` attribute at the target resource's `ref` output. Never build the object by hand:

```hcl
resource "meshstack_landingzone" "this" {
  spec = {
    platform_ref                  = meshstack_platform.this.ref # not { uuid = ...metadata.uuid }
    mandatory_building_block_refs = [meshstack_building_block_definition.platform_tenant_id.ref]
  }
}
```

`ref` carries the `kind` next to the identifier, in exactly the shape the pointing attribute
expects. A hand-built object usually omits the `kind`, so a reference to the wrong kind of object is
caught only when meshStack rejects the apply.

Ten resources expose `ref`: `meshstack_building_block`, `meshstack_building_block_definition`,
`meshstack_building_block_runner`, `meshstack_integration`, `meshstack_landingzone`,
`meshstack_location`, `meshstack_platform`, `meshstack_platform_type`, `meshstack_tenant` and
`meshstack_workspace`. A literal or a variable stays where no `ref` can replace it: an object this
configuration does not manage, a ref wired in from elsewhere, and the user and group bindings, whose
`role_ref` and `target_ref` take an identifier with no `kind`. A building block is ordered against a
definition *version*, which `ref` does not identify — that one takes `version_latest` or
`version_latest_release`.

<!-- scorecard-checks: platform_lifecycle_ignore_availability -->
## `meshstack_platform` Lifecycle

Every `meshstack_platform` resource must include a `lifecycle` block that ignores changes to `availability`:

```hcl
resource "meshstack_platform" "this" {
  # ...
  lifecycle {
    ignore_changes = [spec.availability]
  }
}
```

The `availability` field controls publication state and access restrictions. meshStack operators modify this after initial deployment (e.g. to publish a platform to users) — Terraform must not reset it on subsequent applies.

<!-- scorecard-checks: child_bb_run_postcondition -->
## Ordering Child Building Blocks

A starterkit or composition orders `meshstack_building_block` resources on behalf of a tenant.
Every one of those resources must assert that its run succeeded:

```hcl
resource "meshstack_building_block" "example" {
  # ...
  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }
}
```

Copy those four lines verbatim, in every child building block, including the ones in
`reference-architectures/` — the scorecard only scans `modules/`, so nothing checks them for you.
Do not write a per-block message: OpenTofu prints the resource address and the file and line of the
failing postcondition, and `self` supplies the uuid and the status, so the identical message names
the specific block anyway.

**Why the check has to be in the configuration.** From meshStack provider v0.25.2 on, a run that
does not succeed never fails the apply — the provider warns, keeps the block, and the next plan
runs it again ([provider #277](https://github.com/meshcloud/terraform-provider-meshstack/issues/277)).
That is right for the building block itself — OpenTofu and Terraform taint a resource whose
creation errors and always replace a tainted resource, so the old behaviour destroyed a building
block that a single re-run would have repaired. It is wrong for a starterkit, whose own run would
report `SUCCEEDED` while the tenant is missing what it ordered.

The provider cannot supply the check for you. The plugin protocol has no way to declare a lifecycle
condition — `precondition` and `postcondition` are core configuration constructs — and even if it
had one, the only way a provider can fail an apply is an error diagnostic from `Create`, which is
the tainting that keeping the block was about. A postcondition is evaluated after the resource is
written to state and after every taint call site, so it fails the parent run and still leaves the
child block in state for the next apply to repair.

**Keep `wait_for_completion` at its default `true`.** With `false` the create returns while the run
is still `PENDING` or `IN_PROGRESS`, and the postcondition then fails on a run that had not
finished.

**What a non-`SUCCEEDED` status does on the next plan** depends on whether the provider plans a
re-run:

- `FAILED` or `ABORTED` — the provider plans an in-place re-run, which makes `status` unknown in the
  plan, so the postcondition moves to the apply. If the re-run does not succeed either, the
  postcondition is what fails that apply: the provider itself only ever warns about a run status.
- One of the four `WAITING_FOR_*` statuses (`OPERATOR_INPUT`, `USER_INPUT`, `DEPENDENT_INPUT`,
  `APPROVAL`) — the provider plans no re-run, `status` stays known, and the postcondition **fails
  the plan**, not just the apply. That is the intended signal: no apply will fix this by itself, so
  someone has to supply the input or approve the run in meshPanel. A child block that is *meant* to
  park — one whose definition requires an approval — is the one case for a looser condition, e.g.
  `contains(["SUCCEEDED", "WAITING_FOR_APPROVAL"], self.status.status)`.

