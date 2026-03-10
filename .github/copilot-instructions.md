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
- Must include `required_providers`.
- Never include `provider` configuration.
- Reference modules using Git URLs and ref names. Use interpolation in module source, it's supported by OpenTofu.

### Shared Variable Conventions

The following variables must appear in every `meshstack_integration.tf`.

To source modules from the hub, include a hub variable which determines the git reference to use.
You may extend `variable "hub"` with additional fields as needed (e.g. `base_url`), but `git_ref`
is always required.

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
```

Integrating with meshStack requires context, like a workspace where the resource will be managed.

```hcl
# Shared meshStack context — always include this variable
variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
}
```

Use these variables in the implementation block of building block definitions.

```hcl
resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
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
- [ ] `meshstack_integration.tf` present at the module root
- [ ] Provider versions pinned with `~>`
- [ ] Variables in `snake_case`
- [ ] `buildingblock/README.md` with YAML front-matter
- [ ] `buildingblock/APP_TEAM_README.md` with shared responsibility matrix
- [ ] `ref_name` uses `var.hub.git_ref` — no hardcoded `"main"`
- [ ] Test file covering positive, negative, and naming collision scenarios
- [ ] `logo.png` included in `buildingblock/`
- [ ] No trailing whitespace
