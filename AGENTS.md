# meshstack-hub — Agent Instructions

## Purpose of this Repository

The meshstack-hub is the **canonical Terraform module registry** for meshStack integrations — an
Artifactory-like catalog with a UI at hub.meshcloud.io. It is the **monorepo for all IaC
building blocks** that can be imported into any meshStack instance.

> CI runs `tf validate` and `terraform-docs` on every module — it does **not** run `tf plan`.
> Planning and applying happens in IaC runtimes (LCF/ICF) that consume modules from this repo.

---

<!-- scorecard-checks: buildingblock_dir, versions_tf, backplane -->
## Module Structure

Every module follows a two-tier layout. The `backplane` tier is optional and should be omitted for simple building blocks that require no cloud-side setup (e.g. those that receive all credentials as static inputs).

```
modules/<cloud-provider>/<service-name>/
├── backplane/          # optional — Infrastructure/permissions setup (run by platform team)
│   ├── main.tf         # Omit entirely for simple building blocks that need no cloud-side setup
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── README.md
├── buildingblock/      # Actual service resources (run by meshStack per tenant)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── provider.tf
│   ├── README.md          # YAML front-matter required (see below)
│   ├── logo.png
│   └── *.tftest.hcl
└── meshstack_integration.tf   # Example wiring into a meshStack instance
```

The `modules/<cloud-provider>/` directory itself holds the platform's own `README.md` (front-matter
with `name` and `description`) and its `logo.png` or `logo.svg`.

**Logos are always named `logo.png` or `logo.svg`** and colocated with what they depict — platforms,
building blocks and reference architectures alike. The website generator copies them into its
generated asset directories under `website/public/assets/`; never add files there by hand.

---

<!-- scorecard-checks: meshstack_integration, backplane_source_hub_git_ref, ref_name_hub_git_ref -->
## `meshstack_integration.tf` Conventions

These files are examples showing how to integrate building block and platform modules with a meshStack instance.
They are starting points that should cover the simplest use case.
A secondary purpose of these files is to serve as a ready-to-use Terraform module root that IaC runtimes can source directly.

- Must use variables for required user inputs.
- Must include `required_providers` block at the **bottom** of the file.
- Keep variable blocks at the top of the file, followed immediately by output blocks; keep `variable "meshstack"` and `variable "hub"` at the end of the variable section.
- Cloud-provider-specific variables must be flat with a provider prefix (e.g. `azure_tenant_id`, `aws_region`). Do **not** group them into a single provider object like `variable "azure" { type = object({...}) }`.
- Cross-cutting concerns (e.g. workload identity federation) may use an `object({})` variable when the fields are logically inseparable.
- `locals` blocks are allowed when they improve readability/reuse, but place them below variable and output sections.
- Avoid top-of-file banner comments in `meshstack_integration.tf`.
- Never include `provider` configuration.
- Reference modules using Git URLs with `?ref=${var.hub.git_ref}`. This keeps both the `buildingblock` implementation path and the optional `backplane` module source pinned by a single variable. Example:
  ```hcl
  module "backplane" {
    source = "github.com/meshcloud/meshstack-hub//modules/<provider>/<service>/backplane?ref=${var.hub.git_ref}"
  }
  ```
  The `const = true` attribute on `var.hub` allows Terraform/OpenTofu to resolve the interpolation at `init` time.

<!-- scorecard-checks: required_providers_meshstack -->
### Required providers

Every `meshstack_integration.tf` must declare the `meshcloud/meshstack` provider in a
`required_providers` block. Use a minimum version constraint with `>=` (e.g. `>= 0.20.0`).
Root configurations (ICF/LCF) that source hub modules are responsible for strict version
pinning via their `.terraform.lock.hcl` files.

```hcl
terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.20.0"
    }
  }
}
```

<!-- scorecard-checks: variable_hub, variable_meshstack, bbd_draft, bbd_tags_forwarded, bbd_inputs_explicit_defaults -->
### Shared Variable Conventions

The following variables must appear in every `meshstack_integration.tf`.

To source modules from the hub, include a hub variable which determines the git reference to use.
You may extend `variable "hub"` with additional fields as needed (e.g. `base_url`), but `git_ref`
is always required.

```hcl
# Shared Hub reference — always include this variable
variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}
```

The `const = true` attribute (OpenTofu ≥ 1.12 / Terraform ≥ 1.15) marks `var.hub` for early static evaluation during `terraform init`, which is required to interpolate `var.hub.git_ref` inside module `source` strings. `variable "hub"` must satisfy all `const` constraints:
- Its value must come from a `default`, `.tfvars` file, or `TF_VAR_*` environment variable — **never** from a resource, data source, or dynamic local.
- It must **not** have `sensitive = true` or `ephemeral = true`.

**If a `meshstack_building_block_definition` input's `argument` field references a variable, that variable must have an explicit default** — do not rely on nested `optional()` defaults (for example via a bare `default = {}`), since some downstream consumers don't evaluate Terraform's object-attribute defaulting and would see unset fields instead. Keep the `optional()` type constraints regardless — they still document intent and protect callers who omit keys.

Always use `var.hub.bbd_draft` for the `draft` field of `version_spec` in `meshstack_building_block_definition` resources.

<!-- scorecard-checks: output_bbd -->
### Exposing Building Block Definition References

When a `meshstack_integration.tf` exposes building block definition references for compositions, use a single object output named `building_block_definition`:

```hcl
output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}
```

Integrating with meshStack requires context, like a workspace where the resource will be managed.

```hcl
# Shared meshStack context — always include this variable
variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
}
```

Use these variables in the implementation block of building block definitions. Always forward `var.meshstack.tags` to the BBD `metadata.tags` field so that workspace-level tags are propagated to the building block definition.

```hcl
resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }
  # ... other required fields ...
    implementation = {
      terraform = {
        repository_url  = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path = "modules/<provider>/<service>/buildingblock"
        ref_name        = var.hub.git_ref   # always use var.hub.git_ref, never hardcode "main"
      }
    }
  # ...
}
```

<!-- scorecard-checks: platform_lifecycle_ignore_availability -->
### `meshstack_platform` Lifecycle

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

---

<!-- scorecard-checks: provider_pinned -->
## Variable Conventions

- Always use `snake_case` for variable names: `monthly_budget_amount`, not `monthlyBudgetAmount`
- **Cloud-provider-specific variables** in `meshstack_integration.tf` must be **flat** (not grouped into a single object) and prefixed with the cloud provider name: `azure_tenant_id`, `aws_region`, `gcp_project_id`, `stackit_project_id`
- **Cross-cutting concerns** like workload identity federation settings may be grouped into an `object({})` typed variable (e.g. `variable "workload_identity"`) when the fields are logically inseparable
- Only `variable "meshstack"` and `variable "hub"` use shared `object({})` conventions across all integrations
- Use minimum version constraints (`>= X.Y.Z`) for all providers — never `~>` and never an exact pin. This applies to **every** `required_providers` block in the module: both tiers (`backplane/` and `buildingblock/`, including nested submodules) and `meshstack_integration.tf`, in whichever file declares them (`versions.tf`, `provider.tf`, …). Strict pinning is the responsibility of root configurations (ICF/LCF) via `.terraform.lock.hcl`.
  Both tiers matter because they are consumed together: a hub e2e test module loads the backplane and the buildingblock into one configuration, so their constraints must intersect on a version that exists. A `~>` or exact pin in either tier caps the whole configuration — and silently caps the e2e suite.
- Terraform baseline: `>= 1.12.0` to cover OpenTofu v1.12.0 with `const` variable support (requires OpenTofu ≥ 1.12 or Terraform ≥ 1.15)

---

## Scorecard

The repository includes a scorecard tool that checks module maturity across four categories:
**Core Structure**, **Integration**, **Azure Backplane**, and **Testing**.

```sh
# Full report
node tools/scorecard/scorecard.mjs

# Single module
node tools/scorecard/scorecard.mjs --module=<provider>/<service>

# Generate a fix prompt for a module's violations
node tools/scorecard/scorecard.mjs --module=<provider>/<service> --fix
```

To fix violations, see [.agents/skills/module/SKILL.md](.agents/skills/module/SKILL.md#workflow-fixing-scorecard-violations).

---

## AWS Backplane Identity Conventions

See [.agents/references/aws-backplane.md](.agents/references/aws-backplane.md) for the full AWS backplane identity conventions, including WIF (OIDC + IAM role) and cross-account (IAM user + CloudFormation StackSet) patterns, required variables/outputs, and the AWS backplane checklist.

## Azure Backplane Identity Conventions

See [.agents/references/azure-backplane.md](.agents/references/azure-backplane.md) for the full Azure backplane identity conventions, including UAMI patterns, WIF wiring, required variables/outputs, and the Azure backplane checklist.

---

<!-- scorecard-checks: readme_frontmatter, logo, app_team_readme, bbd_readme, bbd_readme_no_leading_heading, bbd_readme_shared_responsibility, no_documentation_md_output -->
## Documentation Requirements

See [.agents/references/bbd-readme.md](.agents/references/bbd-readme.md) for the complete BBD readme specification, template, and checklist.

**`buildingblock/README.md`** — must include YAML front-matter:

```yaml
---
name: <Human-readable name>
supportedPlatforms:
  - <platform-id> # e.g. aws, azure, stackit
description: One-sentence description of what the module provisions.
requiresBackplane: false # optional — see below
---
```

`requiresBackplane: false` is optional and declares that the module needs no cloud-side setup, so
the scorecard treats the missing `backplane/` tier as not applicable instead of a gap. Only set it
for building blocks that genuinely provision nothing cloud-side (e.g. those receiving all
credentials as static inputs) — add a comment above it saying why.

**User-facing readme — two patterns depending on module completeness:**

- **Modules with `meshstack_integration.tf`** (full building blocks): user-facing readme lives in the `readme` field of `meshstack_building_block_definition.spec`. Always use `chomp(<<-EOT)` inline — never `file()` or a separate file (one-file copy/paste requirement). See [.agents/references/bbd-readme.md](.agents/references/bbd-readme.md) for full spec.

- **Modules without `meshstack_integration.tf`** (standalone building blocks): place the user-facing readme at `buildingblock/APP_TEAM_README.md`. meshStack uses this file as a fallback when no inline readme is available. The same content requirements apply (plain-text description first, usage motivation, examples, shared responsibility table).

The readme (inline or `APP_TEAM_README.md`) must include:

- A **plain-text description** as the first content — no leading `#` heading.
- **Usage motivation**: who this building block is for and when to use it.
- **Usage examples**: 1–2 concrete developer scenarios.
- **Shared responsibility matrix**: markdown table with `✅` / `❌` emojis.

**`backplane/README.md`** — documentation relevant to platform engineers deploying the backplane. Include an overview of what the backplane provisions, required permissions/roles, and operational notes.

**Anti-pattern: `documentation_md` output** — do **not** add a `documentation_md` output to backplane modules. This is a legacy pattern. Documentation must instead be split into:
- User-facing content → BBD `readme` field in `meshstack_integration.tf` (or `APP_TEAM_README.md` if no integration file)
- Platform-engineer-facing content → `backplane/README.md`

---

## Hub as a Shim for IaC Runtimes

Modules in this repo are **consumed** by IaC runtimes (LCF, ICF, customer deployments).
Those runtimes are shim layers — they reference Hub modules and should not re-implement logic here.

When prototyping locally in an IaC runtime, use relative module includes to avoid constant
branch pushes:

```hcl
# In LCF/ICF terragrunt.hcl — for local prototyping only
source = "../../../meshstack-hub/modules/stackit/git-repository/buildingblock"
```

Do **not** commit these relative paths; switch back to the Hub GitHub URL before merging.

---

## Reference Architectures

Reference architectures are curated, end-to-end blueprints that show how multiple Hub building blocks
fit together to deliver a complete platform capability. They live in the `reference-architectures/`
directory at the repo root, one folder per architecture — mirroring how modules are laid out.

### Folder structure

```
reference-architectures/<cloud>-<capability>/
├── README.md                  # front-matter + body (this is the architecture)
├── logo.png                   # optional — falls back to the cloud provider logos on the website
├── <cloud>-<capability>.dot   # optional — diagram source
├── <cloud>-<capability>.svg   # optional — generated, committed alongside
├── meshstack_integration.tf   # optional — makes the architecture importable into meshStack
└── buildingblock/             # optional — Terraform for the importable architecture
```

The folder name is the architecture id used in website URLs. A folder without a `README.md` is
ignored by the website generator.

### File format

```yaml
---
name: Human-Readable Architecture Name
description: >
  A concise paragraph explaining the architecture's purpose and value proposition.
cloudProviders:
  - azure
buildingBlocks:
  - path: azure/aks
    role: Short description of this block's role in the architecture.
  - path: aks/github-connector
    role: Short description of this block's role in the architecture.
---

# Architecture Title

Markdown body with overview, architecture diagram, how-it-works walkthrough,
getting-started steps, and shared responsibility matrix.
```

### Conventions

- Folder name: `<cloud>-<capability>` (e.g. `azure-kubernetes`, `stackit-kubernetes`), with the
  architecture itself in `README.md`.
- Logo: colocate as `logo.png` (or `logo.svg`) in the architecture folder, the same convention
  `buildingblock/logo.png` uses. The website generator copies it to
  `website/public/assets/reference-architecture-logos/<id>.png` — never add files there by hand,
  that directory is generated and gitignored.
- `buildingBlocks[].path` must match a module path under `modules/` (e.g. `azure/aks`).
- The Markdown body should include an **architecture diagram** showing how blocks relate — see
  [Diagrams](#diagrams) for the format.
- Include a **shared responsibility matrix** (platform team vs. application team) with ✅ / ❌ emojis.
- Include **Getting Started** steps with prerequisites and deployment order.

### Checklist for New Reference Architectures

- [ ] Folder `reference-architectures/<cloud>-<capability>/` containing a `README.md` with YAML front-matter
- [ ] `logo.png` colocated in the architecture folder (no logo files added under `website/public/assets/`)
- [ ] `name`, `description`, `cloudProviders`, and `buildingBlocks` fields present
- [ ] Every `buildingBlocks[].path` references an existing module in `modules/`
- [ ] Every `buildingBlocks[].role` has a one-sentence description
- [ ] Body includes: overview, architecture diagram, how-it-works, getting started, shared responsibilities
- [ ] Diagram committed as `<name>.dot` + generated `<name>.svg`, referenced with `![...](<name>.svg)`
- [ ] `task diagrams` run and the regenerated SVG committed
- [ ] No trailing whitespace

---

## Diagrams

Architecture diagrams are **Graphviz DOT** source committed next to the Markdown that uses them, with
the rendered SVG committed alongside (`<name>.dot` + `<name>.svg`, referenced as `![...](<name>.svg)`).
Run `task diagrams` to re-render and `task diagrams:check` to verify; CI fails on a stale SVG.

See [.agents/references/diagrams.md](.agents/references/diagrams.md) for the full conventions: the
shared colour palette and emoji vocabulary that keep diagrams looking like one family, the standard
preamble, composition (separate systems into top-level clusters), layout control (`rank=same`,
`constraint=false`, `splines=ortho`) with its traps, label discipline, why Mermaid was dropped, and
the diagram checklist.

---

<!-- scorecard-checks: e2e_tests, e2e_tftest -->
## End-to-End Testing

Modules that can be smoke-tested against a live meshStack instance should include an `e2e/` directory alongside the module root.

See [.agents/skills/e2e-test/SKILL.md](.agents/skills/e2e-test/SKILL.md) (the `e2e-test` skill) for the full e2e testing conventions, including the `e2e/` structure, `test_context` wiring, `e2e/main.tf` and `*.tftest.hcl` conventions, the new-test checklist, and how to run and debug tests via the smoke-test runner.

---

## Tenant Migration

Moving meshTenants between meshPlatforms — for example off a hand-built custom platform onto one deployed
by a reference architecture — cannot use meshStack's import path when the landing zone carries a mandatory
building block definition. The tenants must instead adopt their existing cloud resources through the
building block's Terraform state.

See [.agents/skills/tenant-migration/SKILL.md](.agents/skills/tenant-migration/SKILL.md) (the
`tenant-migration` skill) for the workflow, the tenant classes, the per-tenant runbook, building block
state doctoring and the meshStack API cookbook that the migration relies on.

---

## Checklist for New Modules

- [ ] `backplane/` (optional) and `buildingblock/` with all required files
- [ ] `meshstack_integration.tf` present at the module root
- [ ] Provider versions use minimum constraint (`>=`) in `versions.tf` and `meshstack_integration.tf`
- [ ] Variables in `snake_case` with cloud-provider prefix in `meshstack_integration.tf` (e.g. `azure_tenant_id`)
- [ ] `buildingblock/README.md` with YAML front-matter
- [ ] BBD `readme` field uses `chomp(<<-EOT)` inline (no `file()`), starts with plain-text description (no `#` heading), and includes usage motivation, 1–2 examples, and a shared responsibility table with ✅ / ❌ — see [.agents/references/bbd-readme.md](.agents/references/bbd-readme.md)
- [ ] If no `meshstack_integration.tf`: `buildingblock/APP_TEAM_README.md` is present with the same content requirements (plain-text description first, motivation, examples, shared responsibility table)
- [ ] `meshstack_integration.tf` declares `meshcloud/meshstack` in `required_providers`
- [ ] `meshstack_integration.tf` uses `variable "hub" { type = object({git_ref = string}) }` and `variable "meshstack" { type = object({owning_workspace_identifier = string}) }`
- [ ] `meshstack_integration.tf` references backplane via GitHub URL with `?ref=${var.hub.git_ref}` (e.g. `github.com/meshcloud/meshstack-hub//modules/<provider>/<service>/backplane?ref=${var.hub.git_ref}`) — never a hardcoded commit SHA or relative `./backplane` path
- [ ] `variable "hub"` has `const = true`
- [ ] Variables referenced from `meshstack_building_block_definition` input `argument` fields have explicit defaults (never rely on `optional()` defaults via bare `default = {}`)
- [ ] `ref_name` uses `var.hub.git_ref` — no hardcoded `"main"`
- [ ] `version_spec.draft` uses `var.hub.bbd_draft`
- [ ] `metadata.tags = var.meshstack.tags` in `meshstack_building_block_definition` resource
- [ ] Tags are modeled via `var.meshstack.tags` (no separate top-level `variable "tags"` in integrations)
- [ ] `building_block_definition` output is exposed as `{ uuid, version_ref }` with `version_ref` using `bbd_draft ? version_latest : version_latest_release`
- [ ] `locals` blocks (if used) appear below variables and outputs
- [ ] `terraform { required_providers { ... } }` block is at the **bottom** of `meshstack_integration.tf`
- [ ] `meshstack` and `hub` variables are at the end of the variable section
- [ ] `logo.png` included in `buildingblock/`
- [ ] No `documentation_md` output in `backplane/` — use BBD `readme` field and `backplane/README.md` instead
- [ ] `meshstack_platform` resources include `lifecycle { ignore_changes = [spec.availability] }`
- [ ] No trailing whitespace
- [ ] **Azure modules**: also follow the [Azure Backplane Checklist](.agents/references/azure-backplane.md#checklist-for-azure-backplanes)
