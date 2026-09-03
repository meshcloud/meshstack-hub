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
    ├── main.tf        # Test root module — sources the meshstack_integration.tf and creates a building block instance
    ├── terraform.tf   # required_providers block (no version pins needed here)
    └── tests/
        └── <test-name>.tftest.hcl   # tftest assertions on building block outputs
```

---

## Invocation protocol (single source of truth)

`e2e/main.tf` takes a **single `test_context` grab-bag** the smoke-test runner dumps **verbatim** as
one var-file (keeping the runner module-agnostic). Declare **only the fields your module reads**;
object-type conversion drops the rest. Its full shape is the `test_context` output in
[`../meshstack-smoke-test/modules/test_context/main.tf`](../../../../meshstack-smoke-test/modules/test_context/main.tf).

The mode is selected **solely by the optional `bbd_version_ref` field**:

| `bbd_version_ref` | Mode | Who runs it | What it does |
|---|---|---|---|
| null (unset) | **build-from-source** | meshstack-smoke-test (hub-e2e) | Builds the BBD from hub source via the relative `../` module + ephemeral backplane, then orders a building block. |
| set | **foundation** | foundation repos (likvid/internal-cloudfoundation) | The foundation already deployed the BBD; the test only orders a building block against the given version ref. |

```hcl
variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
    hub_git_ref = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Cloud resource IDs. Needed in build-from-source mode (to provision the backplane) and, for
    # tenant-level building blocks, also in foundation mode (the target_ref tenant id).
    fixtures = optional(object({
      stackit = object({
        project_id     = string
        mesh_tenant_id = string
      })
    }))
  })
  nullable = false
}
```

Conventions that keep this clean and correct:

- **The discriminator is `bbd_version_ref` alone — not `fixtures`.** `fixtures` is orthogonal to the
  mode: tenant-level building blocks need `fixtures.<cloud>.mesh_tenant_id` for `target_ref` in *both*
  modes, so you cannot key the mode off `fixtures` being present. Declare `fixtures = optional(...)`
  and let each module decide whether it needs it (workspace-level blocks typically only need it in
  build-from-source; tenant-level blocks need it in both). Its inner shape stays fully required, so a
  half-populated `fixtures` is unrepresentable.
- **`hub_git_ref` is required in both modes.** It is passed into the integration module's `const`
  `hub.git_ref`, whose backplane `source` (`?ref=${var.hub.git_ref}`) is statically evaluated at
  **init — regardless of `count`**. It must therefore resolve to a non-null string even in foundation
  mode (where the module is not built), so it cannot be `optional`. The foundation already knows its
  deployed ref and passes it through (`dependency.deployment.outputs.e2e.hub.git_ref`).
- **Always-shared fields are required**: `workspace`, `name_suffix`, and `hub_git_ref` are used (or
  statically evaluated) in both modes.
- **Cloud resource IDs live under `fixtures`** (e.g. `var.test_context.fixtures.stackit.project_id`),
  never as a flat top-level field.
- **`test_context` describes the environment, not the test case.** A flag that selects *which variant
  of the module under test to build* (e.g. a sync vs async implementation) does not belong in
  `test_context` — it belongs in a **root variable of the `e2e/` module**, pinned per test file. See
  [Covering several variants of one module](#covering-several-variants-of-one-module). Putting it in
  `test_context` forces the variant to be chosen before `tofu test` starts, which pushes a
  test-matrix concern out of the hub and into whatever invokes it.

### Secrets

**No secret is ever a `test_context` field.** The grab-bag is built from state a CI job can read, so
a secret in it would have to be persisted somewhere it does not belong.

A secret reaches the module one of two ways:

- The provider reads it from **its own standard environment variable** (cloud credentials). The
  module declares nothing.
- The module declares a **flat root variable** for it, when the value is also needed as an input to
  the module under test (e.g. `stackit_git_forgejo_token`, `github_app_private_key`). The smoke-test
  runner exports every secret it holds as `TF_VAR_<name>`, so declaring the variable is all it takes
  — name it exactly as the runner does.

---

## `e2e/main.tf` conventions

- **Source the module under test via a relative path** to the module root (where
  `meshstack_integration.tf` lives), **not** a GitHub URL — so tests run against the local branch
  without a push. Gate it on the mode with `count` (build-from-source only), and map the module's
  flat provider inputs from `fixtures`:

```hcl
module "my_stackit_module" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0   # build-from-source mode only
  source = "../"                                              # relative path to the meshstack_integration.tf root
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
  stackit_project_id = var.test_context.fixtures.stackit.project_id
}
```

- When the module under test **depends on other Hub modules** (e.g. a starterkit that composes a
  git-repository and connector module), also source those dependencies using **relative paths**
  (e.g. `"../../stackit/git-repository"`, `"../forgejo-connector"`).

- **Resolve the version ref in a `local`** — from `bbd_version_ref` in foundation mode, otherwise
  from the built module:

```hcl
locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.my_stackit_module[0].building_block_definition.version_ref
}
```

- Create a `meshstack_building_block` resource that exercises the building block end-to-end.
  Reference `test_context` directly (it is non-null in both modes). The provider's
  `building_block_definition_version_ref` takes `{ uuid }` only — extract it explicitly.

- **Always add `depends_on = [module.<integration_module>]`** to `meshstack_building_block.this`.
  WIF federated identity providers have no Terraform dependents (nothing references their outputs),
  so OpenTofu schedules their destruction in parallel with the BB delete run. This causes the BB
  delete run to fail with 401s because the cloud WIF trust is already gone before the delete run
  can authenticate. The explicit `depends_on` forces the BB resource (including its delete run) to
  be fully destroyed before any backplane resources are torn down.

```hcl
resource "meshstack_building_block" "this" {
  depends_on          = [module.<integration_module>]   # prevents teardown race with WIF providers
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

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

- Name the file `<cloud>_<service>_hub.tftest.hcl` (e.g. `building_block_noop_hub.tftest.hcl`), or
  `<cloud>_<service>_<variant>_hub.tftest.hcl` when a module has several variants.
- Always assert `status.status == "SUCCEEDED"` as the first check.
- Assert meaningful output values (URLs, strings, booleans) to validate the building block executed
  correctly. Every output `value` is a `jsonencode`d string — read it with
  `jsondecode(<res>.status.outputs["<name>"].value)` (a CODE/JSON output decodes twice).
- The same test file runs in **both** invocation modes (smoke-test via `tofu test`, foundation via
  `terragrunt test`). Reference **`output.<name>`**, never `var.test_context.*` — `test_context` is
  null in foundation mode and would crash the assertion.
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

### The exception: a test whose subject *is* a change

Some behaviour only exists as a change to something that already exists. A `TAG` input is the
example: meshStack resolves it from a tag on the workspace, project, payment method or landing zone,
and re-resolves it when that tag changes or when the object it reads from is reassigned. A fresh
building block per value proves resolution and nothing else — the follow-the-metadata behaviour needs
one building block and a tag that moves under it. That takes shared state, so it takes one file.

Neither reason above applies to such a test, and saying why is what keeps the exception narrow:

- It never touches `display_name`, so the rename-without-a-run trap is not in play.
- It never touches `building_block_definition_version_ref`, so the released-version-only upgrade path
  is not in play either. The building block's own `spec` identity is fixed for the whole file; only
  the objects *around* it change.

Two things such a file has to get right, both learned the hard way:

- **Bump an input the provider tracks in every mutating run.** A TAG input is resolved server-side,
  so nothing in the configuration tells the provider a tag moved — it plans no change and waits for
  nothing. Bumping a `USER_INPUT` makes it issue an update and await a run, and that run resolves the
  current tag values. Be explicit in the file about what this does and does not prove: the value a
  tag holds now reaches the next run; *not* that the tag edit alone triggered a run. The provider
  surfaces no way to attribute a run to an edit.
- **Let meshStack's own run get out of the way first.** meshStack triggers a run when a tag a
  building block reads changes. That run competes with the one the test triggers: `awaitRun` polls
  the block's aggregate status and stops at the first terminal one, so the wrong run's outputs can
  land in state, and meshStack rejects an update issued while a run is in flight. A `time_sleep`
  between the tag writes and the building block, replaced per scenario via `triggers`, is enough —
  and it belongs in the fixture module, not in a polling script.

`modules/meshstack/noop/e2e/tests/building_block_noop_tag_inputs_hub.tftest.hcl` is the worked
example. If a test does not clear this bar, use separate files.

---

## Running tests

### Running locally

From `../meshstack-smoke-test` after `source setup-env.sh`:

```bash
task hub:e2e:run MODULE=stackit/storage-bucket
task hub:e2e:run MODULE=stackit/storage-bucket TF_LOG=debug
task hub:e2e:run MODULE=azure/resource-group FILTER=tests/azure_resource_group_hub.tftest.hcl
task hub:e2e   # run all hub e2e tests
```

The runner: applies `modules/test_context` to resolve `hub_git_ref` from the committed SHA, exports
its output as a temp `.tfvars.json`, then runs `tofu test` in the module's `e2e/` directory.

### Running in CI (GitHub Actions)

The CI workflow lives in the **`meshcloud/meshstack-smoke-test`** repo (`../meshstack-smoke-test`),
not in the hub — it is `.github/workflows/smoke-test.yml`. It has **a single-module dispatch input** called `module` that's used to verify exactly one module.

Trigger the workflow using gh cli and poll for the result.

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

- [ ] `e2e/` directory exists at the module root
- [ ] Single `variable "test_context"` grab-bag (`nullable = false`); declares only the fields the module reads
- [ ] Mode selected **solely** by the optional `bbd_version_ref` (typed `optional(object({ uuid = string }))`); `fixtures` is orthogonal (tenant-level blocks need it in both modes)
- [ ] `fixtures` is `optional()` with its inner shape fully required (no half-populated fixtures)
- [ ] Always-shared fields (`workspace`, `name_suffix`, `hub_git_ref`) are required, not `optional()`
- [ ] Cloud resource IDs sourced from `var.test_context.fixtures.*` (not flat `test_context` fields)
- [ ] Scalar secrets are top-level `nullable` vars with `default = null` (foundation mode omits them)
- [ ] Module sourced via relative path (not a GitHub URL), gated with `count = var.test_context.bbd_version_ref == null ? 1 : 0`
- [ ] `hub.git_ref = var.test_context.hub_git_ref` — no hardcoded `"main"`
- [ ] Version ref resolved in a `local` (`bbd_version_ref` in foundation mode, else the built module)
- [ ] `building_block_definition_version_ref = { uuid = local.version_ref.uuid }` — provider only accepts `{ uuid }`, extract it explicitly
- [ ] `meshstack_building_block` has `depends_on = [module.<integration_module>]` to prevent WIF teardown race (delete run must finish before backplane resources are destroyed)
- [ ] `meshstack_building_block` has `wait_for_completion = true`
- [ ] tftest asserts `status.status == "SUCCEEDED"` and key outputs (references `var.test_context.*` directly — non-null in both modes)
- [ ] Variant flags (sync/async and similar) are **root variables of the `e2e/` module** with a default, not `test_context` fields
- [ ] One `.tftest.hcl` file per variant, pinning the flag in a file-level `variables` block — never several `run` blocks sharing one file's state
- [ ] …unless the subject of the test *is* a change to a live building block's surroundings — then one file with shared state, and see [The exception](#the-exception-a-test-whose-subject-is-a-change) for the two things it must get right
- [ ] Writes into a long-lived shared fixture go to a per-run ephemeral slice named from `name_suffix`, owned by the `e2e/` module and included in the building block's `depends_on`
- [ ] State the live apply cannot reach is covered by a mocked `<cloud>_<service>_unit.tftest.hcl` in `e2e/tests/`, targeting `module { source = "../buildingblock" }` — and only where the two bars are cleared (worth testing, unreachable by the apply); anything the apply *can* reach is an assertion on the apply instead
- [ ] Every mocked run is mutation-checked: break the module, watch the run fail
