---
name: e2e-test
description: >
  Write, run, and debug hub e2e tests for meshstack-hub modules. Use when asked to add, fix, or run
  an end-to-end smoke test for any building block module. Covers structure, test_context wiring,
  conventions, the new-test checklist, running via the smoke-test runner or from a foundation repo, and debugging failures.
---

# Hub E2E Test Skill

This skill is the authoritative reference for hub e2e test modules. Hub modules that can be tested
against a live meshStack instance include an `e2e/` directory alongside the module root.

The purpose of these e2e tests is to ensure correct operation of building blocks in two different contexts.
- **hub module e2e test**: deploy the hub module with an ephemeral backplane against a dev meshStack, ensuring that a fresh deployment of a hub module works out of the box using the latest version of all meshStack ecosystem components (i.e. meshStack, the official meshStack terraform provider, building block runners etc.). These tests are run by the meshcloud internal `meshcloud/meshstack-smoke-test` repo.
- **foundation e2e tests**: deploy the hub module with a long-lived backplane against a production meshStack instance and deploy an ephemeral building block to verify that the building block as deployed by end users via meshStack is functional. These tests are run by foundation repositories like that set up enterprise landing zones on cloud platforms and integrate them with meshStack.

meshcloud maintains the public [likvid-bank/likvid-cloudfoundation](https://github.com/likvid-bank/likvid-cloudfoundation) foundation repo and meshcloud `meshcloud/internal-cloudfoundation` for internal testing.

To successfully work across these repositories, always read their AGENTS.md file to discover skills in these repositories.

---

<!-- scorecard-checks: e2e_tests -->
## Structure

```
modules/<cloud-provider>/<service-name>/
└── e2e/
    ├── main.tf        # the building block and what probes it — mode-agnostic
    ├── terraform.tf   # required_providers block (no version pins needed here)
    ├── modes/
    │   ├── hub/        # builds the BBD from hub source with an ephemeral backplane
    │   └── foundation/ # passes through the BBD version the foundation deployed
    └── tests/
        └── <cloud>_<service>.tftest.hcl   # assertions on the building block
```

---

## Invocation protocol (single source of truth)

The smoke-test runner dumps one `test_context` var-file, verbatim, for every module. That keeps the
runner module-agnostic. Its full shape is the `test_context` output of the `test_context` module in
`meshstack-smoke-test`.

### The two modes

`test_context.mode` selects the mode:

| `mode` | Who runs it | What happens |
|---|---|---|
| unset / `"hub"` | meshstack-smoke-test | Builds the BBD from hub source with an ephemeral backplane, then orders a building block. |
| `"foundation"` | foundation repos (likvid/trial/internal-cloudfoundation) | The BBD is already published. Looks it up by display name and orders a building block against it. |

Modules still on the older `count` gate instead read the mode off `bbd_version_ref` being set.
Switch one to `mode` when migrating it to the `modes/` layout.

The mode picks a **module source**, not a `count`:

```hcl
locals {
  mode = try(var.test_context.mode, "hub")
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context      = var.test_context
  backplane_secrets = { ... }
}
```

OpenTofu evaluates a module `source` statically at `tofu init`, so **only the selected mode is
installed**. Foundation mode never resolves the hub build tree.

### Why not `count`

A `count` gate on each backplane module forces every field that only one mode needs to be
`optional()`. That set grows with the backplane, and a half-filled `test_context` becomes
representable with nothing to reject it. One module per mode lets each mode re-type `test_context`
itself and keep every field required, so a missing field fails at the module boundary:

```
Error: Invalid value for input variable
  ... declared at modes/hub/main.tf:6,1-24: attribute "dns_zone_name" is required.
```

Most modules still use the older `count` gate. Migrate one when you next touch it. Do not convert
them all in one change.

### The root module

`e2e/main.tf` holds only what both modes share: the `meshstack_building_block` and anything probing
what it deployed. `test_context` is an untyped pipe here, because the mode modules own the type:

```hcl
variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.name_suffix)
    error_message = "test_context must provide workspace and name_suffix."
  }
}
```

Add to the validation whatever else the root reads. A tenant-level block also reads
`fixtures.<cloud>.mesh_tenant_id` for its `target_ref`, in both modes.

### The mode modules

`e2e/modes/hub/` and `e2e/modes/foundation/` expose the same contract:

```hcl
output "version_ref" { value = ... }   # { uuid = string }
```

`modes/foundation` builds nothing. It finds the published definition through the meshStack API and
returns the version ref to order against:

```hcl
data "meshstack_building_block_definitions" "published" {
  workspace_identifier = var.test_context.workspace
}

locals {
  # Must match `spec.display_name` in ../../meshstack_integration.tf.
  display_name = "SKE Starterkit"

  # `one` yields null when nothing matches, and fails outright on a duplicate display name.
  definition = one([for d in data.meshstack_building_block_definitions.published.building_block_definitions
  : d if d.spec.display_name == local.display_name])

  version = var.test_context.bbd_draft ? try(local.definition.version_latest, null) : try(local.definition.version_latest_release, null)
}
```

Look the definition up; do not take its version ref as an input. That is what keeps a foundation
smoke test down to **one credential, the meshStack API key** — reading it from the deployment's
terraform state instead would need cloud credentials for the state backend, and that state also
holds the backplane's own secrets. It also means the test targets what a user of the foundation
actually sees, and works for a definition published by any means.

Guard both misses with an output `precondition`, so the failure names the cause rather than
surfacing as a null attribute: no definition under that display name, and a definition whose
`bbd_draft` does not match what the foundation deployed (a draft has no released version).

`test_context` in this mode is therefore just `{ workspace, bbd_draft }` — all static values a
foundation can spell out in HCL, no `dependency` on the deployment unit.

A provider that only one mode needs belongs in that mode module, not in the root — foundation mode
then never installs it. A module holding a provider block may not take `count`, `for_each` or
`depends_on`, so keep those off the `module "definition"` block.

`modes/hub` builds the BBD. Source the module under test by **relative path**, never a GitHub URL,
so tests run against the local branch without a push:

```hcl
module "under_test" {
  source = "../../../" # the directory holding meshstack_integration.tf
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}
```

`hub_git_ref` is required in **hub mode only**. It reaches a module `source`
(`?ref=${var.hub.git_ref}`) inside the integration module, which OpenTofu evaluates statically at
init. Foundation mode never installs `modes/hub`, so it needs no hub ref.

When the module under test depends on other hub modules (a starter kit composing a git-repository
and a connector), source those by relative path too.

### Secrets

**No secret is ever a `test_context` field.** The grab-bag is built from state a CI job can read, so
a secret in it would have to be persisted somewhere it does not belong.

A secret reaches the module one of two ways:

- The provider reads it from **its own standard environment variable** (cloud credentials). Declare
  nothing.
- The root declares a **flat variable** with `default = null`, when the module under test needs the
  value as an input. The runner exports every secret it holds as `TF_VAR_<name>`, and only a root
  module reads `TF_VAR_*` — so the root declares them and pipes them down as one object.

`modes/hub` re-types that object with every field required and rejects nulls:

```hcl
variable "backplane_secrets" {
  type      = object({ ... })
  sensitive = true
  nullable  = false

  validation {
    # `nullable = false` rejects only the whole object, so check the attributes.
    condition     = alltrue([for secret in values(var.backplane_secrets) : secret != null])
    error_message = "Every backplane secret must be set; the runner exports them as TF_VAR_<name>."
  }
}
```

`modes/foundation` declares the same argument as unused `any`. A module block has one argument list
for both sources, so both modes must accept it.

Marking the variable `sensitive` is belt-and-braces: sensitivity travels with the value, so a
sensitive input stays sensitive even in a variable not declared as such. It never changes the value.

### The building block

```hcl
resource "meshstack_building_block" "this" {
  depends_on          = [module.definition]
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "smoke-test-<name>-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }
    # inputs: one `value = jsonencode(...)` per input (jsonencode strings too, e.g.
    # jsonencode("x"), jsonencode(1), jsonencode(true)). Sensitive inputs instead use
    # `sensitive = { secret_value = ... }`.
    inputs = { ... }
  }
}
```

The provider takes `{ uuid }` only, so extract it explicitly.

`depends_on = [module.definition]` orders teardown as well as create. One state holds the block and
everything `modes/hub` built, so the delete run finishes before any of it is destroyed. Without it,
OpenTofu may destroy WIF federated identity providers in parallel with the delete run, which then
fails with 401s because the cloud trust is already gone. If the delete run fails, the whole destroy
graph aborts and leaves the backplane in `errored_test.tfstate` for the runner to reclaim.

### Isolating a shared mutable fixture

Some building blocks provision *into* a long-lived fixture rather than creating something disposable
— `meshstack/github-workflow`, for instance, has its backplane commit workflow files into a fixture
GitHub repository. Exercising the backplane honestly means those writes really happen, so pointing
them at the fixture's main line rewrites shared history on every run. That is tolerable nightly and
not tolerable hourly.

Give each case its **own ephemeral slice of the fixture**, created and destroyed by the e2e module:

```hcl
resource "github_branch" "ephemeral" {
  repository    = local.github_repository_name
  branch        = "e2e/github-workflow-${local.execution_mode}-${var.test_context.name_suffix}"
  source_branch = var.test_context.fixtures.github.branch # base branch to fork from
}
```

- **Own it in the `e2e/` module, not the backplane.** A real platform team wants its workflows on a
  durable branch it chose; ephemerality is a property of the test. Keeping it here also means no new
  fixture inputs — reuse the credentials the module under test already receives — and it works in
  foundation mode too.
- **Name it from `name_suffix` plus any variant discriminator.** `name_suffix` is a fresh timestamp
  per run, so a leaked slice can never block a later run, and the name says which run and which case
  leaked it.
- **Make teardown ordered.** Add the fixture slice to the building block's `depends_on`: the delete
  run needs the destroy workflow to still be there, and OpenTofu would otherwise be free to delete
  the branch in parallel with the delete run.
- **Accept the leak.** `tofu test` destroys even on failure, but a hard kill (cancelled job, dead
  runner) leaves the slice behind, and nothing reclaims it. That is a deliberate trade: an orphaned
  git ref is cheap and attributable, unlike an orphaned cloud resource. Say so rather than implying
  cleanup is guaranteed.

A useful fact if the fixture is a GitHub repository: a workflow **can** be dispatched on a
non-default branch even though the file is absent from the default branch, and the run executes that
branch's copy. `GET /actions/workflows` stays empty in that state, which makes it look unregistered —
it is not. So no stub workflow on the default branch is needed.

### Workspace-level vs tenant-level `target_ref`

```hcl
# Workspace-level building block (no cloud tenant):
target_ref = {
  kind = "meshWorkspace"
  name = var.test_context.workspace
}

# Tenant-level building block (cloud tenant required) — fixtures.<cloud>.mesh_tenant_id is provided
# in BOTH modes for tenant-level blocks (the foundation supplies the tenant id it deployed against):
target_ref = {
  kind = "meshTenant"
  uuid = var.test_context.fixtures.azure.mesh_tenant_id
}
```

---

<!-- scorecard-checks: e2e_tftest -->
## `e2e/tests/*.tftest.hcl` conventions

- Name the file `<cloud>_<service>.tftest.hcl`, or `<cloud>_<service>_<variant>.tftest.hcl` when a
  module has several variants. Older modules carry a `_hub` suffix from when the file was hub-only.
- Always assert `status.status == "SUCCEEDED"` as the first check.
- Assert meaningful output values (URLs, strings, booleans) to validate the building block executed
  correctly. Every output `value` is a `jsonencode`d string — read it with
  `jsondecode(<res>.status.outputs["<name>"].value)` (a CODE/JSON output decodes twice).
- One file serves both modes. Assert on the **building block only** — that is the one thing both
  modes produce. The backplane does not exist in foundation mode, so nothing may assert on it.
- Use `file("${path.root}/tests/<name>.expected.*")` for large expected values (JSON, Markdown) to
  keep assertions readable.

### Mocked unit runs, for what the apply cannot reach

A live apply cannot produce every state a building block has to handle: a directory that is missing
a user, an empty input collection, an upstream that returns nothing. Where such a state is worth
covering, add a **second file in `e2e/tests/`** whose runs target the building block directly with
mocked providers:

```hcl
# e2e/tests/<cloud>_<service>_unit.tftest.hcl
mock_provider "azuread" {}

run "unresolved_members_are_reported" {
  module {
    source = "../buildingblock"
  }
  # variables, override_data, assertions ...
}
```

- They run in the same `tofu test` invocation as the apply file, need no credentials, and finish in
  well under a second. `tofu init` in `e2e/` still applies, so the smoke-test runner's var-file is
  required to get that far — which is why they live here and not under `buildingblock/`.
- **`path.root` is the module under test inside such a run**, not `e2e/`. Read an expected-output
  fixture as `file("${path.root}/../e2e/tests/<name>.expected.md")`.
- `override_data` / `override_resource` values may not call functions or reference variables, so a
  mocked collection has to be spelled out literally. A `for` over a list of the one or two
  attributes that matter keeps the schema-required rest out of the way.

**Be strict about what earns a run here.** Two bars, both required:

1. The behaviour is worth testing — a user-visible failure, not an internal detail.
2. The apply genuinely cannot reach it. If it can, **add an assertion to the apply instead**; that
   assertion runs against real infrastructure and is worth more than any mock.

Variable-validation cases usually clear neither bar. Neither does anything reachable only through a
module input the building block definition does not expose — that is dead configuration surface, not
covered behaviour. When a run is dropped for these reasons, say so in the commit rather than
relocating it.

Confirm each run actually bites by mutating the module and watching it fail. A mocked run that
passes against broken code is worse than no run at all.

### Covering several variants of one module

Some modules build a materially different building block definition depending on an input — for
example `meshstack/github-workflow`, whose `github_async` flag swaps the apply and destroy workflows
and the declared outputs. Model each variant as **its own test file**, selected by a **root variable
of the `e2e/` module** with a safe default:

```hcl
# e2e/main.tf — the variant is a root variable, not a test_context field
variable "github_async" {
  type        = bool
  default     = false
  description = "Exercise the async variant instead of the sync one."
}
```

```hcl
# e2e/tests/meshstack_github_workflow_async_hub.tftest.hcl
variables {
  github_async = true
}

run "meshstack_github_workflow_async_hub" {
  # assertions specific to this variant — no need to guard them on the variant flag
}
```

Whatever runs the tests needs no per-variant plumbing: a single `tofu test` invocation picks up
every `*.tftest.hcl` file, so one job covers all variants.

**Use separate files, not several `run` blocks in one file.** The two are not interchangeable:

| | Two test files | Two `run` blocks in one file |
|---|---|---|
| State | One per file | Shared across runs |
| Teardown | End of each file, before the next starts | Once, at end of file |
| Resource lifecycle | Fresh create → assert → destroy per variant | Variant 2 **updates variant 1's objects in place** |

Sharing state across `run` blocks is wrong for building blocks specifically, and not just untidy.
`meshstack_building_block` applies a `display_name` change as an in-place rename that **does not
trigger a building block run**, and a `building_block_definition_version_ref` change as an **in-place
upgrade** that the backend only accepts towards the latest *released* version. Since e2e definitions
are built as drafts (`bbd_draft = true`), a second `run` block would either silently assert against
the first variant's run or be rejected outright — never provision the second variant cleanly.

Separate files also **serialize the variants for free**: `tofu test` executes test files sequentially
and destroys each file's resources before starting the next. Variants that contend for the same
external resource (the same workflow files in a fixture repository, say) therefore cannot race, with
no external locking or concurrency group needed. Verify assumptions like this against the OpenTofu
version in use rather than trusting them.

---

## Running tests

Hub e2e tests run in GitHub Actions only. The environment they need exists just as the Actions
secrets that `meshstack-smoke-test` pushes, so there is no local test run. Push your branch, then
dispatch the workflow and read the job logs:

```bash
gh workflow run smoke-test.yml -f module=stackit/storage-bucket -f meshstack_hub_ref=refs/pull/<nr>/head
gh run watch
```

The workflow is `.github/workflows/smoke-test.yml` in `meshcloud/meshstack-smoke-test`. Its `module`
input runs exactly one e2e case. The runner applies the `test_context` module to resolve
`hub_git_ref` from the committed SHA, writes it to a temp `.tfvars.json`, then runs `tofu test` in
the module's `e2e/` directory.

Foundation mode runs from the foundation repo's own `smoke-test.yml`, dispatched per case with a
path prefix:

```bash
gh workflow run smoke-test.yml -f prefix=platforms/ske/starterkit/e2e   # in likvid-cloudfoundation
```

That job holds one secret, the meshStack API key. If a foundation smoke test needs a cloud
credential, a state backend or a terragrunt `dependency`, the mode module is taking something it
should be looking up.

---

## Debugging

### Hub changes must be pushed before running
The runner resolves `hub_git_ref` from the current commit SHA and verifies it exists on a remote branch:

```
ERROR: Hub commit <sha> has not been pushed to any remote branch.
```

Fix: push your branch first. Uncommitted local changes only produce a warning — the test still runs
against the committed SHA. Only the `e2e/` directory itself is executed from local disk.

### Errored test state

If `tofu test` fails mid-apply, OpenTofu writes `e2e/errored_test.tfstate`.
Interacting with the test state is useful for manually cleaning up cloud resources when tofu fails to do it:

```bash
cd modules/<provider>/<service>/e2e
tofu state list -state=errored_test.tfstate
rm errored_test.tfstate   # after manual cleanup if needed
```

### Fetching building block run logs

The most likely cause of a test failure is a building block run failure, manifesting as an error message like this

> Failed to await building block creation
> item in failed state: building block 97cc733e-9611-460a-8bbf-d930466cfc94
> reached FAILED state during creation, check the building block run logs in meshStack

Use the `tools/debug/get-bb-run-logs.mjs` helper to fetch step-by-step Terraform logs for a
building block run without manual curl calls:

```bash
# From meshstack-hub after: source ../meshstack-smoke-test/setup-env.sh
BB_UUID="<uuid from log or errored_test.tfstate>"
node tools/debug/get-bb-run-logs.mjs "$BB_UUID"
```

To get the UUID from an errored test state:
```bash
tofu state show -state=errored_test.tfstate 'meshstack_building_block.this' | grep uuid
```


## Advanced Debugging

### Debugging with `tofu apply` (bypass `tofu test` teardown)

When iterating on a new building block, it's sometimes faster to use `tofu apply` directly
in the `e2e/` directory instead of `tofu test`. This bypasses the test framework's automatic
teardown and you can more quickly iterate on the deployed state, making changes across `meshstack_integration.tf`,
the `backplane` and `buildingblock` module as well as the test assertions themselves.

Step 1, produce the test_context var file
```bash
# From meshstack-smoke-test: produce the var-file
tofu -chdir=modules/test_context apply -auto-approve -var="hub_dir=$(pwd)/../meshstack-hub"
ctx=$(tofu -chdir=modules/test_context output -json test_context)
printf '{"test_context":%s}\n' "$ctx" > /tmp/test-vars.tfvars.json

# From meshstack-hub: run module directly directly
cd modules/<provider>/<service>/e2e
tofu init -upgrade -var-file=/tmp/test-vars.tfvars.json -var="my_secret=$SECRET"
tofu apply -auto-approve -var-file=/tmp/test-vars.tfvars.json -var="my_secret=$SECRET"
```

After debugging, **always destroy explicitly**:

```bash
tofu destroy -auto-approve -var-file=/tmp/test-vars.tfvars.json -var="my_secret=$SECRET"
```

### Provider override for local meshstack provider binary

When testing against pre-release versions of the meshStack terraform provider is required, ie. due to impending breaking
changes or using pre-release features:

`source setup-override-provider.sh` in `meshstack-smoke-test` must be run from the
`meshstack-smoke-test` directory itself, not from the hub repo. When sourced from a different
working directory, the script correctly resolves its own path via `BASH_SOURCE[0]`.

After sourcing, export the config file to affect all tofu invocations in the current shell:
```bash
cd /path/to/meshstack-smoke-test
source setup-override-provider.sh
# TF_CLI_CONFIG_FILE is now exported — all tofu calls in this shell use the local binary
```

---

## Checklist for New E2E Tests

- [ ] `e2e/main.tf` holds only the building block and what probes it; both modes live under `e2e/modes/`
- [ ] `variable "test_context"` is `type = any`, `nullable = false`, with a `validation` for the fields the root itself reads
- [ ] `local.mode` comes from `try(var.test_context.mode, "hub")`; `module "definition"` sources `./modes/${local.mode}`
- [ ] `modes/foundation` looks the published definition up by display name — it takes no version ref, so the foundation needs no credential but the meshStack API key
- [ ] Both mode modules expose the same `output "version_ref"`
- [ ] Each mode module re-types `test_context` as an `object` with every field it needs required — no `optional()`
- [ ] `modes/hub` sources the module under test by relative path (not a GitHub URL) and passes `hub.git_ref = var.test_context.hub_git_ref`
- [ ] Secrets are flat root variables with `default = null`, piped down as one object, re-typed in `modes/hub` with a validation that rejects nulls
- [ ] `building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }` — the provider accepts `{ uuid }` only
- [ ] `meshstack_building_block` has `depends_on = [module.definition]` and `wait_for_completion = true`
- [ ] One mode-agnostic `.tftest.hcl` file; assertions touch the building block only
- [ ] Variant flags (sync/async and similar) are **root variables of the `e2e/` module** with a default, not `test_context` fields
- [ ] One `.tftest.hcl` file per variant, pinning the flag in a file-level `variables` block — never several `run` blocks sharing one file's state
- [ ] Writes into a long-lived shared fixture go to a per-run ephemeral slice named from `name_suffix`, owned by the `e2e/` module and included in the building block's `depends_on`
- [ ] State the live apply cannot reach is covered by a mocked `<cloud>_<service>_unit.tftest.hcl` in `e2e/tests/`, targeting `module { source = "../buildingblock" }` — and only where the two bars are cleared (worth testing, unreachable by the apply); anything the apply *can* reach is an assertion on the apply instead
- [ ] Every mocked run is mutation-checked: break the module, watch the run fail
