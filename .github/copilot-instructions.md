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

### `meshstack_integration.tf` as a single-file module

Each `meshstack_integration.tf` is a **self-contained single-file Terraform module**. It must
include `variable`, `output`, `terraform {}`, `locals`, and `resource` blocks all in one file —
do **not** create separate `variables.tf`, `outputs.tf`, or `versions.tf` alongside it.
This keeps the integration compact and easy to call as a sub-module from composition modules.

### Building block logos / symbols

Use `provider::meshstack::load_image_file()` (requires meshstack provider `>= 0.19.3`) to set
the `symbol` attribute on `meshstack_building_block_definition` resources. Reference the
`logo.png` already present in the `buildingblock/` directory:

```hcl
resource "meshstack_building_block_definition" "example" {
  spec = {
    symbol = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")
    # ...
  }
}
```

This keeps logo management inside the hub — callers don't need to provide their own assets.

---

## `meshstack_integration.tf` Conventions

These files are **examples** showing how to register a module in a meshStack instance.
They are starting points to be adapted, not production configs.

### Shared variable conventions

All `meshstack_integration.tf` files must use a consistent set of `variable` blocks so that
IaC runtimes (LCF/ICF) can wire them together uniformly. Use structured `object({})` types to
group related variables:

```hcl
# Shared Hub reference — always include this variable
variable "hub" {
  type = object({
    git_ref = string
  })
  default = {
    git_ref = "main"
  }
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo."
}

# Shared meshStack context — always include this variable
variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = "Shared meshStack context passed down from the IaC runtime."
}
```

Use these variables in the implementation block:

```hcl
implementation = {
  terraform = {
    repository_url  = "https://github.com/meshcloud/meshstack-hub.git"
    repository_path = "modules/<provider>/<service>/buildingblock"
    ref_name        = var.hub.git_ref   # always use var.hub.git_ref, never hardcode "main"
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }
  ...
}
```

You may extend `variable "hub"` with additional fields as needed (e.g. `base_url`), but `git_ref`
is always required.

### Backplane module reference

Always reference the backplane with a **relative path**:

```hcl
module "backplane" {
  source = "./backplane"
  # ...
}
```

### Cross-module references (composition modules)

When a `meshstack_integration.tf` needs to call **another hub module** (e.g. the AKS starterkit
calling `modules/github/repository`), use a **git URL** with a **hardcoded ref** — never a
relative `../../` path. Relative upward traversal breaks when the module is sourced via a git URL
from LCF/ICF/meshkube, because Terraform only downloads the specified subdirectory.

```hcl
# ✅ Cross-module reference — git URL with hardcoded ref
module "github_repo_bbd" {
  source = "github.com/meshcloud/meshstack-hub//modules/github/repository?ref=main"
  # ...
}
```

**Rules:**
- `./backplane` → relative path (same module subtree, always works)
- `../../other/module` → **git URL** with hardcoded `?ref=<tag-or-branch>` (cross-module)
- `var.hub.git_ref` → used only in `implementation.terraform.ref_name` of BBD resources, NOT
  in `source` arguments (Terraform does not support variable interpolation in `source`)

**Ref management:** The hardcoded refs in git URL `source` lines default to `"main"` during
development. A Go CI tool (planned) will walk the hub module dependency tree bottom-up and
update these refs to specific tags on release. Leaf modules (no cross-module deps) are updated
first, then composition modules.

### ❌ Avoid these patterns

```hcl
# ❌ locals instead of variables — makes values non-configurable by runtimes
locals {
  owning_workspace_identifier = "my-workspace"
  github_org                  = "my-org"
}

# ❌ provider blocks inside mesh_integration.tf — the Hub UI renders these
provider "meshstack" { ... }

# ❌ absolute GitHub source URL for backplane — use relative path instead
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/s3_bucket/backplane?ref=main"
}

# ❌ relative path for cross-module refs — breaks when sourced via git URL
module "github_repo_bbd" {
  source = "../../github/repository"
}

# ❌ standalone meshstack_hub_git_ref variable — use variable "hub" { type = object({git_ref=string}) } instead
variable "meshstack_hub_git_ref" { ... }

# ❌ hardcoded ref — always use var.hub.git_ref
ref_name = "main"
```

---

## Backplane Patterns

**AWS:** IAM users + CloudFormation StackSets for cross-account roles; assume role for target account access.

**Azure:**
- Custom role definitions scoped to subscription or management group
- Optional service principal creation with Workload Identity Federation (WIF); falls back to app password
- Two-tier networking roles: `buildingblock_deploy` (main) and `buildingblock_deploy_hub` (VNet peering, ACR, Key Vault)

---

## Variable Conventions

- Always use `snake_case` for variable names: `monthly_budget_amount`, not `monthlyBudgetAmount`
- Group logically related inputs into `object({})` typed variables (e.g. `var.hub`, `var.meshstack`)
- Pin provider versions with `~> X.Y.Z` (allow patch updates, not minor/major)
- Terraform baseline: `>= 1.3.0`

---

## Documentation Requirements

**`buildingblock/README.md`** — must include YAML front-matter:

```yaml
---
name: <Human-readable name>
supportedPlatforms:
  - <platform-id>   # e.g. aws, azure, stackit
description: One-sentence description of what the module provisions.
---
```

**`buildingblock/APP_TEAM_README.md`** — user-facing; must include:
- What the building block does and when to use it
- Usage examples
- Shared responsibility matrix (platform team vs. application team)
- Best practices

---

## Testing

Test files (`.tftest.hcl`) must cover:
- Positive scenarios (valid configurations)
- Negative scenarios (invalid inputs / validation rules)
- Naming collision prevention

Standard test users (use these identifiers consistently):

```hcl
{ meshIdentifier = "likvid-tom-user",     username = "likvid-tom@meshcloud.io",     roles = ["admin", "Workspace Owner"] }
{ meshIdentifier = "likvid-daniela-user", username = "likvid-daniela@meshcloud.io", roles = ["user", "Workspace Manager"] }
{ meshIdentifier = "likvid-anna-user",    username = "likvid-anna@meshcloud.io",    roles = ["reader", "Workspace Member"] }
```

---

## STACKIT-Specific Notes

- STACKIT Git is based on Forgejo/Gitea — use the Gitea provider, not a generic Git provider
- Forgejo/Gitea **user management** (org membership, team assignments) must be handled in the
  backplane; it is currently incomplete in the STACKIT git-repository module
- The STACKIT project building block (`modules/stackit/project/`) is the mandatory Landing Zone
  building block and should be the first dependency for any STACKIT composition

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
- [ ] Provider versions pinned with `~>`
- [ ] Variables in `snake_case`
- [ ] `buildingblock/README.md` with YAML front-matter
- [ ] `buildingblock/APP_TEAM_README.md` with shared responsibility matrix
- [ ] `meshstack_integration.tf` uses `variable "hub" { type = object({git_ref = string}) }` and `variable "meshstack" { type = object({owning_workspace_identifier = string}) }`
- [ ] `meshstack_integration.tf` uses relative `./backplane` source (no absolute GitHub URL)
- [ ] `ref_name` uses `var.hub.git_ref` — no hardcoded `"main"`
- [ ] No `provider` blocks in `meshstack_integration.tf`
- [ ] Test file covering positive, negative, and naming collision scenarios
- [ ] `logo.png` included in `buildingblock/`
- [ ] No trailing whitespace
