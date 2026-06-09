---
name: e2e-test
description: >
  Write, run, and debug hub e2e tests for meshstack-hub modules. Use when asked to add, fix, or run
  an end-to-end smoke test for any building block module. Covers structure, test_context wiring,
  conventions, the new-test checklist, running via the smoke-test runner, and debugging failures.
---

# Hub E2E Test Skill

This skill is the authoritative reference for hub e2e tests. Modules that can be smoke-tested
against a live meshStack instance include an `e2e/` directory alongside the module root. Tests are
run by the meshstack-smoke-test repo (`../meshstack-smoke-test`).

For the runner architecture, commands, and conventions, see
[`../meshstack-smoke-test/AGENTS.md`](../../../../meshstack-smoke-test/AGENTS.md).

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

## `test_context` field inventory

`e2e/main.tf` declares a single `variable "test_context"` object. The `test_context` output is
defined in
[`../meshstack-smoke-test/modules/test_context/main.tf`](../../../../meshstack-smoke-test/modules/test_context/main.tf).
Declare only the fields your module actually uses, but **at minimum** include `hub_git_ref`,
`workspace`, `project`, and `name_suffix`:

| Field | Description |
|---|---|
| `hub_git_ref` | Committed SHA of the meshstack-hub checkout — always include |
| `workspace` | `"smoke-test"` — shared smoke-test workspace |
| `project` | smoke-test project identifier |
| `name_suffix` | Timestamp string (e.g. `20260608143022`) — include in resource names for uniqueness |

Cloud resource IDs always live under `fixtures` — use `var.test_context.fixtures.stackit.project_id`,
not a flat `stackit_project_id` field on `test_context` (that pattern is outdated).

For additional secrets not in `test_context` (SA keys, tokens), declare separate top-level
`sensitive` variables — `setup-env.sh` in meshstack-smoke-test provides them via `TF_VAR_*`.

```hcl
variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string

    fixtures = object({
      stackit = object({
        project_id     = string
        mesh_tenant_id = string
      })
    })
  })
  nullable = false
}
```

---

## `e2e/main.tf` conventions

- Source the module under test using a **relative path** to the module root (where
  `meshstack_integration.tf` lives), **not** a GitHub URL. This ensures tests run against the local
  branch without requiring a push. Map the module's flat provider inputs from `fixtures`:

```hcl
module "my_stackit_module" {
  source = "../"     # relative path to the meshstack_integration.tf root
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref   # always use hub_git_ref — never hardcode "main"
    bbd_draft = true
  }
  stackit_project_id = var.test_context.fixtures.stackit.project_id
}
```

- When the module under test **depends on other Hub modules** (e.g. a starterkit that composes a
  git-repository and connector module), also source those dependencies using **relative paths**
  (e.g. `"../../stackit/git-repository"`, `"../forgejo-connector"`).

- Create a `meshstack_building_block_v2` resource to exercise the building block end-to-end. Pass
  `module.<name>.building_block_definition.version_ref` **directly** — do not unwrap it as
  `{ uuid = module.<name>.building_block_definition.version_ref.uuid }`:

```hcl
resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.my_module.building_block_definition.version_ref

    display_name = "smoke-test-<name>-${var.test_context.name_suffix}"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.test_context.workspace
    }
    inputs = { ... }
  }
}
```

### Workspace-level vs tenant-level `target_ref`

```hcl
# Workspace-level building block (no cloud tenant):
target_ref = {
  kind = "meshWorkspace"
  name = var.test_context.workspace
}

# Tenant-level building block (cloud tenant required):
target_ref = {
  kind = "meshTenant"
  uuid = var.test_context.fixtures.azure.mesh_tenant_id
}
```

---

<!-- scorecard-checks: e2e_tftest -->
## `e2e/tests/*.tftest.hcl` conventions

- Name the file `<cloud>_<service>_hub.tftest.hcl` (e.g. `building_block_noop_hub.tftest.hcl`).
- Always assert `status.status == "SUCCEEDED"` as the first check.
- Assert meaningful output values (URLs, strings, booleans) to validate the building block executed
  correctly.
- Use `file("${path.root}/tests/<name>.expected.*")` for large expected values (JSON, Markdown) to
  keep assertions readable.

---

## Running tests

From `../meshstack-smoke-test` after `source setup-env.sh`:

```bash
task hub:e2e:run MODULE=stackit/storage-bucket
task hub:e2e:run MODULE=stackit/storage-bucket TF_LOG=debug
task hub:e2e:run MODULE=azure/resource-group FILTER=tests/azure_resource_group_hub.tftest.hcl
task hub:e2e   # run all hub e2e tests
```

The runner: applies `modules/test_context` to resolve `hub_git_ref` from the committed SHA, exports
its output as a temp `.tfvars.json`, then runs `tofu test` in the module's `e2e/` directory.

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
tofu state show -state=errored_test.tfstate 'meshstack_building_block_v2.this' | grep uuid
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
- [ ] `variable "test_context"` includes `hub_git_ref`, `workspace`, `project`, `name_suffix`
- [ ] Cloud resource IDs sourced from `var.test_context.fixtures.*` (not flat `test_context` fields)
- [ ] Module sourced via relative path (not a GitHub URL)
- [ ] `hub.git_ref = var.test_context.hub_git_ref` — no hardcoded `"main"`
- [ ] `building_block_definition_version_ref` uses the full `version_ref` object directly
- [ ] `meshstack_building_block_v2` has `wait_for_completion = true`
- [ ] tftest.hcl asserts `status.status == "SUCCEEDED"` and key outputs
