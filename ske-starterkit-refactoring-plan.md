# Plan: Adapt SKE Starterkit to Match AKS Composition Pattern

## Objective

1. **Create a git worktree** at `.worktrees/aks-refactor` for `feature/aks-starter-kit-refactoring` as a reference
2. **Refactor the SKE starterkit** to follow the AKS composition pattern (backplane + child BBDs), using STACKIT components instead of Azure/GitHub equivalents

## Current State Analysis

### AKS Starterkit Pattern (the target pattern)
The refactored AKS starterkit uses a **composition pattern**:
- **`starterkit/backplane/`** — Terraform module that references child BBD `meshstack_integration.tf` modules:
  - `modules/github/repository` → registers the GitHub Repo BBD
  - `modules/aks/github-connector` → registers the GitHub Actions Connector BBD
  - ~~`modules/azure/postgresql` → (optional) registers the PostgreSQL BBD~~ *(out of scope for SKE)*
- **`starterkit/meshstack_integration.tf`** — Single-file module that:
  - Calls `module "backplane" { source = "./backplane" }` to register child BBDs
  - Registers the starterkit BBD itself, wiring child BBD UUIDs as static inputs
  - Exposes `var.github`, `var.aks`, `var.hub`, `var.meshstack`

### SKE Starterkit (current — to be refactored)
Currently uses a **flat pattern**:
- **No real backplane** for the starterkit (only the SKE platform itself has `ske/backplane/`)
- **`starterkit/buildingblock/main.tf`** directly creates meshStack projects, tenants, user bindings, and instantiates the Git repo BBD inline via `meshstack_building_block_v2`
- **`starterkit/meshstack_integration.tf`** — registers the starterkit BBD with `var.starterkit.git_repo_definition_uuid` / `_version_uuid` as manual external inputs

### Existing STACKIT Hub Modules
- **`modules/stackit/git-repository/`** — Already exists with full backplane + buildingblock + `meshstack_integration.tf`. Uses Gitea provider for Forgejo. ✅ Ready to reuse.
- **No Forgejo Actions connector module exists yet** — This needs to be created (analogous to `modules/aks/github-connector/`).

### STACKIT Forgejo Actions Connector (to be created)
Looking at the AKS GitHub Actions connector (`modules/aks/github-connector/`), it:
1. Creates a Kubernetes service account + RBAC in the target namespace
2. Generates a kubeconfig for the service account
3. Stores the kubeconfig as a GitHub Actions environment secret
4. Stores container registry credentials as environment secrets

The STACKIT equivalent would:
1. Create a Kubernetes service account + RBAC in the SKE namespace (same pattern)
2. Generate a kubeconfig for the service account
3. Store secrets in the Forgejo repository (using Gitea provider's `gitea_actions_secret` or via API)
4. No container registry credentials initially (out of scope)

**Note**: Forgejo Actions are similar to GitHub Actions (they share the same runner spec). The connector module pattern is analogous — the difference is the secret storage target (Forgejo repo secrets vs GitHub environment secrets).

## Todos

### 1. `worktree-setup` — Create AKS refactor worktree
Create `.worktrees/aks-refactor` for `feature/aks-starter-kit-refactoring` as side-by-side reference.

### 2. `forgejo-connector-module` — Create `modules/stackit/ske/forgejo-connector/`
New hub module analogous to `modules/aks/github-connector/`:
- **`buildingblock/`**:
  - `main.tf` — Create K8s service account + RBAC in SKE namespace, generate kubeconfig, store as Forgejo Actions secret
  - `variables.tf` — `namespace`, `gitea_base_url`, `gitea_token`, `gitea_organization`, `repository_name`
  - `outputs.tf` — summary output
  - `provider.tf` — kubernetes + gitea providers
  - `versions.tf` — provider version pins
  - `README.md` — with YAML front-matter
  - `APP_TEAM_README.md` — user-facing docs
  - `logo.png` — reuse STACKIT logo
- **`meshstack_integration.tf`** — Single-file module registering the Forgejo connector BBD

### 3. `ske-starterkit-backplane` — Create `modules/stackit/ske/starterkit/backplane/`
New backplane following AKS pattern:
- `main.tf` — References child BBDs:
  - `module "git_repo_bbd"` → sources `../../git-repository` (the existing STACKIT git-repository module)
  - `module "forgejo_connector_bbd"` → sources `../forgejo-connector` (from step 2)
- `variables.tf` — `var.hub`, `var.meshstack`, `var.gitea` (Forgejo credentials)
- `outputs.tf` — child BBD UUIDs for wiring
- `versions.tf` — provider pins

### 4. `ske-starterkit-integration-refactor` — Update `modules/stackit/ske/starterkit/meshstack_integration.tf`
Refactor to match AKS pattern:
- Add `module "backplane" { source = "./backplane" }` call
- Replace `var.starterkit.git_repo_definition_uuid` / `_version_uuid` with `module.backplane.*` outputs
- Add `var.gitea` variable for Forgejo credentials
- Remove manual UUID inputs from `var.starterkit` (they now come from backplane)
- Keep: `var.hub`, `var.meshstack`, `var.aks`→`var.ske` platform identifiers

### 5. `ske-starterkit-buildingblock-update` — Update buildingblock inputs
- Add Forgejo connector inputs (e.g. `forgejo_connector_definition_version_uuid`)
- Wire the connector BBD into the per-tenant composition (similar to how AKS wires `github_actions_connector_definition_version_uuid`)

## Open Questions / Decisions

1. **Forgejo Actions secrets API**: Does the Gitea Terraform provider support `gitea_actions_secret`? If not, we may need `null_resource` + `curl` to the Forgejo API (similar to the existing webhook pattern in `stackit/git-repository/buildingblock/main.tf`).
2. **Container registry**: Out of scope for now — no registry credentials will be pushed (unlike AKS/ACR). Can be added later.

## Out of Scope

- PostgreSQL / persistence building block (AKS has `azure/postgresql` — not relevant for initial SKE starterkit)
