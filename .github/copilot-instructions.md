# GitHub Copilot Instructions — meshstack-hub

## Purpose of this Repository

The meshstack-hub is the **canonical Terraform module registry** for meshStack integrations — an
Artifactory-like catalog with a UI at hub.meshcloud.io. It is the **monorepo for all IaC
building blocks** that can be imported into any meshStack instance.

> CI runs `tf validate` and `terraform-docs` on every module — it does **not** run `tf plan`.
> Planning and applying happens in IaC runtimes (LCF/ICF) that consume modules from this repo.

---

## Module Structure

Every module follows a strict two-tier layout:

```
modules/<cloud-provider>/<service-name>/
├── backplane/          # Infrastructure/permissions setup (run by platform team)
│   ├── main.tf
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
│   ├── APP_TEAM_README.md # User-facing docs with shared responsibility matrix
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
- Must include `required_providers` block at the **bottom** of the file — resources and variables should come first so readers see the important configuration before technical boilerplate).
- Never include `provider` configuration.
- Reference modules using Git URLs and a ref pointing to the feature branch when developing. Once merged into main, the `update-module-refs` tooling in CI pins the ref to an appropriate commit.

### Required providers

Every `meshstack_integration.tf` must declare the `meshcloud/meshstack` provider in a
`required_providers` block.

```hcl
terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
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

### Exposing the BBD Version

When a `meshstack_integration.tf` exposes the building block definition version UUID as an output (needed for compositions), use the following pattern to pin to released versions in production while allowing draft updates during development:

```hcl
output "building_block_definition_version_uuid" {
  description = "UUID of the latest version. In draft mode returns the latest draft; otherwise returns the latest release."
  value       = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest.uuid : meshstack_building_block_definition.this.version_latest_release.uuid
}
```

Integrating with meshStack requires context, like a workspace where the resource will be managed.

```hcl
# Shared meshStack context — always include this variable
variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                         = optional(map(list(string)), {})
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
- Group logically related inputs into `object({})` typed variables (e.g. `var.hub`, `var.meshstack`)
- Pin provider versions with `~> X.Y.Z` (allow patch updates, not minor/major)
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

**`buildingblock/APP_TEAM_README.md`** — user-facing; must include:

- What the building block does and when to use it
- Usage examples
- Shared responsibility matrix (platform team vs. application team)
- Best practices

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

## Checklist for New Modules

- [ ] `backplane/` and `buildingblock/` with all required files
- [ ] `meshstack_integration.tf` present at the module root
- [ ] Provider versions pinned with `~>`
- [ ] Variables in `snake_case`
- [ ] `buildingblock/README.md` with YAML front-matter
- [ ] `buildingblock/APP_TEAM_README.md` with shared responsibility matrix
- [ ] `meshstack_integration.tf` declares `meshcloud/meshstack` in `required_providers`
- [ ] `meshstack_integration.tf` uses `variable "hub" { type = object({git_ref = string}) }` and `variable "meshstack" { type = object({owning_workspace_identifier = string}) }`
- [ ] `meshstack_integration.tf` uses relative `./backplane` source (no absolute GitHub URL)
- [ ] `ref_name` uses `var.hub.git_ref` — no hardcoded `"main"`
- [ ] `version_spec.draft` uses `var.hub.bbd_draft`
- [ ] `building_block_definition_version_uuid` output uses `bbd_draft ? version_latest.uuid : version_latest_release.uuid`
- [ ] `terraform { required_providers { ... } }` block is at the **bottom** of `meshstack_integration.tf`
- [ ] Test file covering positive, negative, and naming collision scenarios
- [ ] `logo.png` included in `buildingblock/`
- [ ] No trailing whitespace
