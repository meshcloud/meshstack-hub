# GitHub Copilot Instructions — meshstack-hub

## Purpose of this Repository

The meshstack-hub is the **canonical Terraform module registry** for meshStack integrations — an
Artifactory-like catalog with a UI at hub.meshcloud.io. It is the **monorepo for all IaC
building blocks** that can be imported into any meshStack instance.

> CI runs `tf validate` and `terraform-docs` on every module — it does **not** run `tf plan`.
> Planning and applying happens in IaC runtimes (LCF/ICF) that consume modules from this repo.

---

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

---

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
- Reference modules using Git URLs and a ref pointing to the feature branch when developing. Once merged into main, the `update-module-refs` tooling in CI pins the ref to an appropriate commit.

### Required providers

Every `meshstack_integration.tf` must declare the `meshcloud/meshstack` provider in a
`required_providers` block. Pin the meshstack provider to the current minor version using
`~> X.Y.0` (e.g. `~> 0.20.0`). This is an exception to the general `~> X.Y.Z` patch-pinning
rule because the meshstack provider is pre-1.0 and minor versions may contain breaking changes.

```hcl
terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
  }
}
```

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
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}
```

Always use `var.hub.bbd_draft` for the `draft` field of `version_spec` in `meshstack_building_block_definition` resources.

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

Use these variables in the implementation block of building block definitions.

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

---

## Variable Conventions

- Always use `snake_case` for variable names: `monthly_budget_amount`, not `monthlyBudgetAmount`
- **Cloud-provider-specific variables** in `meshstack_integration.tf` must be **flat** (not grouped into a single object) and prefixed with the cloud provider name: `azure_tenant_id`, `aws_region`, `gcp_project_id`, `stackit_project_id`
- **Cross-cutting concerns** like workload identity federation settings may be grouped into an `object({})` typed variable (e.g. `variable "workload_identity"`) when the fields are logically inseparable
- Only `variable "meshstack"` and `variable "hub"` use shared `object({})` conventions across all integrations
- Pin provider versions with `~> X.Y.Z` (allow patch updates, not minor/major). **Exception:** the `meshcloud/meshstack` provider is pre-1.0, so pin to the minor version with `~> 0.Y.0` (e.g. `~> 0.20.0`)
- Terraform baseline: `>= 1.11.0` to cover OpenTofu v1.11.0 with write-only/ephemeral attribute support

---

## Documentation Requirements

**`buildingblock/README.md`** — must include YAML front-matter:

```yaml
---
name: <Human-readable name>
supportedPlatforms:
  - <platform-id> # e.g. aws, azure, stackit
description: One-sentence description of what the module provisions.
---
```

**BBD `readme` field** — user-facing documentation lives in the `readme` field of `meshstack_building_block_definition.spec` in `meshstack_integration.tf`. It must include:

- A short plain-text description of what the building block does (no extra sub-heading).
- Usage motivation and examples (1–2 developer scenarios).
- Shared responsibility matrix (platform team vs. application team) as a markdown table with ✅ / ❌ emojis.

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
directory at the repo root as Markdown files with YAML front-matter.

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

- File name: `<cloud>-<capability>.md` (e.g. `azure-kubernetes.md`, `stackit-kubernetes.md`).
- `buildingBlocks[].path` must match a module path under `modules/` (e.g. `azure/aks`).
- The Markdown body should include a **Mermaid diagram** showing how blocks relate.
- Include a **shared responsibility matrix** (platform team vs. application team) with ✅ / ❌ emojis.
- Include **Getting Started** steps with prerequisites and deployment order.

### Checklist for New Reference Architectures

- [ ] Markdown file in `reference-architectures/` with YAML front-matter
- [ ] `name`, `description`, `cloudProviders`, and `buildingBlocks` fields present
- [ ] Every `buildingBlocks[].path` references an existing module in `modules/`
- [ ] Every `buildingBlocks[].role` has a one-sentence description
- [ ] Body includes: overview, architecture diagram, how-it-works, getting started, shared responsibilities
- [ ] No trailing whitespace

---

## Checklist for New Modules

- [ ] `backplane/` (optional) and `buildingblock/` with all required files
- [ ] `meshstack_integration.tf` present at the module root
- [ ] Provider versions pinned with `~>`
- [ ] Variables in `snake_case` with cloud-provider prefix in `meshstack_integration.tf` (e.g. `azure_tenant_id`)
- [ ] `buildingblock/README.md` with YAML front-matter
- [ ] BBD `readme` field in `meshstack_integration.tf` contains description, usage motivation, examples, and shared responsibility table (✅ / ❌)
- [ ] `meshstack_integration.tf` declares `meshcloud/meshstack` in `required_providers`
- [ ] `meshstack_integration.tf` uses `variable "hub" { type = object({git_ref = string}) }` and `variable "meshstack" { type = object({owning_workspace_identifier = string}) }`
- [ ] `meshstack_integration.tf` references backplane via GitHub URL (`github.com/meshcloud/meshstack-hub//modules/<provider>/<service>/backplane?ref=<branch-or-commit>`) — never a relative `./backplane` path
- [ ] `ref_name` uses `var.hub.git_ref` — no hardcoded `"main"`
- [ ] `version_spec.draft` uses `var.hub.bbd_draft`
- [ ] Tags are modeled via `var.meshstack.tags` (no separate top-level `variable "tags"` in integrations)
- [ ] `building_block_definition` output is exposed as `{ uuid, version_ref }` with `version_ref` using `bbd_draft ? version_latest : version_latest_release`
- [ ] `locals` blocks (if used) appear below variables and outputs
- [ ] `terraform { required_providers { ... } }` block is at the **bottom** of `meshstack_integration.tf`
- [ ] `meshstack` and `hub` variables are at the end of the variable section
- [ ] `logo.png` included in `buildingblock/`
- [ ] No trailing whitespace
