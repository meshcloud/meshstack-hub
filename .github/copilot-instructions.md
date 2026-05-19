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
- Reference modules using Git URLs with `?ref=${var.hub.git_ref}`. This keeps both the `buildingblock` implementation path and the optional `backplane` module source pinned by a single variable. Example:
  ```hcl
  module "backplane" {
    source = "github.com/meshcloud/meshstack-hub//modules/<provider>/<service>/backplane?ref=${var.hub.git_ref}"
  }
  ```
  The `const = true` attribute on `var.hub` allows Terraform/OpenTofu to resolve the interpolation at `init` time.

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
  const       = true
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}
```

The `const = true` attribute (Terraform ≥ 1.15 / OpenTofu ≥ 1.12) marks `var.hub` for early static evaluation during `terraform init`, which is required to interpolate `var.hub.git_ref` inside module `source` strings. As a consequence, `variable "hub"` **must** satisfy all `const` constraints:
- Its value must come from a `default`, `.tfvars` file, or `TF_VAR_*` environment variable — **never** from a resource, data source, or dynamic local.
- It must **not** have `sensitive = true` or `ephemeral = true`.

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

---

## Variable Conventions

- Always use `snake_case` for variable names: `monthly_budget_amount`, not `monthlyBudgetAmount`
- **Cloud-provider-specific variables** in `meshstack_integration.tf` must be **flat** (not grouped into a single object) and prefixed with the cloud provider name: `azure_tenant_id`, `aws_region`, `gcp_project_id`, `stackit_project_id`
- **Cross-cutting concerns** like workload identity federation settings may be grouped into an `object({})` typed variable (e.g. `variable "workload_identity"`) when the fields are logically inseparable
- Only `variable "meshstack"` and `variable "hub"` use shared `object({})` conventions across all integrations
- Pin provider versions with `~> X.Y.Z` (allow patch updates, not minor/major). **Exception:** the `meshcloud/meshstack` provider is pre-1.0, so pin to the minor version with `~> 0.Y.0` (e.g. `~> 0.20.0`)
- Terraform baseline: `>= 1.11.0` to cover OpenTofu v1.11.0 with write-only/ephemeral attribute support

---

## Azure Backplane Identity Conventions

Azure backplanes **must** use **User-Assigned Managed Identities (UAMIs)** as the automation
principal for building block execution. Do **not** create Service Principals (SPNs) via
`azuread_application` + `azuread_service_principal`.

### Rationale

- **Self-service**: Platform engineers can deploy UAMIs without invoking a central Entra admin team.
  Creating a UAMI requires only `Managed Identity Contributor` on the subscription — no Entra ID
  `Application.ReadWrite.All` or `Application Administrator` role needed.
- **WIF-native**: UAMIs support federated identity credentials (`azurerm_federated_identity_credential`)
  for meshStack's workload identity federation out of the box.
- **Management Group scope**: UAMIs can hold Azure RBAC role assignments at any scope including
  Management Groups. They can also be assigned Entra directory roles (e.g. Directory Readers).
- **CI/CD testability**: E2E smoke tests run under a GHA UAMI with GitHub WIF in a static
  subscription. Using UAMIs in backplanes means the same identity model is used end-to-end,
  and `tofu test` can deploy and destroy `meshstack_integration.tf` without Entra app registration
  privileges.
- **No secrets rotation**: Unlike SPNs with client secrets, UAMIs with WIF produce no secrets to
  manage or rotate.

### Implementation Pattern

```hcl
# backplane/main.tf — UAMI-based automation principal

resource "azurerm_user_assigned_identity" "buildingblock" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "buildingblock" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                = "subject-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.buildingblock.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.workload_identity_federation.issuer
  subject             = each.value
}

resource "azurerm_role_definition" "buildingblock" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block"
  scope       = var.scope
  permissions { actions = [ /* ... */ ] }
}

resource "azurerm_role_assignment" "buildingblock" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.buildingblock.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.buildingblock.principal_id
}
```

### Backplane Variables (Azure)

Every Azure backplane must accept these variables:

```hcl
variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity and role definition."
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope for role assignment (management group or subscription ID)."
}

variable "location" {
  type        = string
  description = "Azure region for the UAMI resource."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the UAMI will be created."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication."
}
```

### Backplane Outputs (Azure)

```hcl
output "identity" {
  value = {
    client_id    = azurerm_user_assigned_identity.buildingblock.client_id
    principal_id = azurerm_user_assigned_identity.buildingblock.principal_id
    tenant_id    = azurerm_user_assigned_identity.buildingblock.tenant_id
  }
}
```

### What to Avoid

- ❌ `azuread_application` / `azuread_service_principal` — do not create SPNs
- ❌ `azuread_application_password` — no client secrets
- ❌ `existing_principal_ids` / `create_service_principal_name` toggle pattern — unnecessary complexity
- ❌ Conditional WIF-vs-secret logic — always use WIF with UAMIs

### `meshstack_integration.tf` Wiring (Azure)

In the integration file, pass the UAMI client ID as the `ARM_CLIENT_ID` environment variable:

```hcl
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/<service>/backplane?ref=${var.hub.git_ref}"

  name                = var.backplane_name
  scope               = var.azure_scope
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}
```

The `meshstack_integration.tf` must include `azure_resource_group_name` and `azure_location`
variables (flat, provider-prefixed) for the UAMI placement.

### Checklist for Azure Backplanes

- [ ] Uses `azurerm_user_assigned_identity` (not `azuread_application`)
- [ ] Uses `azurerm_federated_identity_credential` (not `azuread_application_federated_identity_credential`)
- [ ] No `azuread_application_password` resources
- [ ] No `create_service_principal_name` / `existing_principal_ids` toggle
- [ ] `workload_identity_federation` variable is non-nullable (always required)
- [ ] Outputs `identity.client_id`, `identity.principal_id`, `identity.tenant_id`
- [ ] `meshstack_integration.tf` includes `azure_resource_group_name` and `azure_location` variables

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

## End-to-End Testing

Modules that can be smoke-tested against a live meshStack instance should include an `e2e/` directory alongside the module root.

### Structure

```
modules/<cloud-provider>/<service-name>/
└── e2e/
    ├── main.tf        # Test root module — sources the meshstack_integration.tf and creates a building block instance
    ├── terraform.tf   # required_providers block (no version pins needed here)
    └── tests/
        └── <test-name>.tftest.hcl   # tftest assertions on building block outputs
```

### `e2e/main.tf` Conventions

- Declare a single `variable "test_context"` object with **at minimum** these fields:

```hcl
variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string
  })
  nullable = false
}
```

Add extra fields (e.g. `forgejo_base_url`, provider tokens) as needed for the module under test.

- Source the module under test using a **relative path** to the module root (where `meshstack_integration.tf` lives), **not** a GitHub URL. This ensures tests run against the local branch without requiring a push.

```hcl
module "my_module" {
  source = "../"     # relative path to the meshstack_integration.tf root
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref   # always use hub_git_ref — never hardcode "main"
    bbd_draft = true
  }
}
```

- When the module under test **depends on other Hub modules** (e.g. a starterkit that composes a git-repository and connector module), also source those dependencies using **relative paths** (e.g. `"../../stackit/git-repository"`, `"../forgejo-connector"`).

- Create a `meshstack_building_block_v2` resource to exercise the building block end-to-end:

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

Pass `module.<name>.building_block_definition.version_ref` **directly** — do not unwrap it as `{ uuid = module.<name>.building_block_definition.version_ref.uuid }`.

### `e2e/tests/*.tftest.hcl` Conventions

- Name the file `<cloud>_<service>_hub.tftest.hcl` (e.g. `building_block_noop_hub.tftest.hcl`).
- Always assert `status.status == "SUCCEEDED"` as the first check.
- Assert meaningful output values (URLs, strings, booleans) to validate the building block executed correctly.
- Use `file("${path.root}/tests/<name>.expected.*")` for large expected values (JSON, Markdown) to keep assertions readable.

### Checklist for New E2E Tests

- [ ] `e2e/` directory exists at the module root
- [ ] `variable "test_context"` includes `hub_git_ref`, `workspace`, `project`, `name_suffix`
- [ ] Module sourced via relative path (not a GitHub URL)
- [ ] `hub.git_ref = var.test_context.hub_git_ref` — no hardcoded `"main"`
- [ ] `building_block_definition_version_ref` uses the full `version_ref` object directly
- [ ] `meshstack_building_block_v2` has `wait_for_completion = true`
- [ ] tftest.hcl asserts `status.status == "SUCCEEDED"` and key outputs

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
- [ ] `meshstack_integration.tf` references backplane via GitHub URL with `?ref=${var.hub.git_ref}` (e.g. `github.com/meshcloud/meshstack-hub//modules/<provider>/<service>/backplane?ref=${var.hub.git_ref}`) — never a hardcoded commit SHA or relative `./backplane` path
- [ ] `variable "hub"` includes `const = true`
- [ ] `ref_name` uses `var.hub.git_ref` — no hardcoded `"main"`
- [ ] `version_spec.draft` uses `var.hub.bbd_draft`
- [ ] `metadata.tags = var.meshstack.tags` in `meshstack_building_block_definition` resource
- [ ] Tags are modeled via `var.meshstack.tags` (no separate top-level `variable "tags"` in integrations)
- [ ] `building_block_definition` output is exposed as `{ uuid, version_ref }` with `version_ref` using `bbd_draft ? version_latest : version_latest_release`
- [ ] `locals` blocks (if used) appear below variables and outputs
- [ ] `terraform { required_providers { ... } }` block is at the **bottom** of `meshstack_integration.tf`
- [ ] `meshstack` and `hub` variables are at the end of the variable section
- [ ] `logo.png` included in `buildingblock/`
- [ ] No trailing whitespace
