# Plan: Make Hub AKS Starterkit Reusable for LCF and Meshkube

## Problem

The hub's `modules/aks/starterkit/meshstack_integration.tf` cannot be reused by either:
- **meshkube** — has 3 diverged inline BBD files with hardcoded locals, missing `ref_name`
- **LCF** — missing the `meshstack_building_block_definition` resource entirely (TODO in `kit/aks/meshplatform/main.tf`)

Additionally, `modules/aks/meshstack_integration.tf` (platform-level) is not callable as a module:
uses hardcoded `locals`, has `provider` blocks, no outputs. Both meshkube and LCF duplicate the
platform+landingzone+meshplatform setup independently.

Root causes:
1. Hub integration uses hardcoded `locals`, undefined `local.image_data_uri`, hardcoded commit SHA for `ref_name`
2. `modules/github/repository/` and `modules/aks/github-connector/` have no `meshstack_integration.tf` — their BBDs are hardcoded inline in meshkube only
3. `modules/azure/postgresql/` also has no `meshstack_integration.tf` (needed for LCF)
4. `modules/aks/meshstack_integration.tf` not reusable as a module — violates hub conventions

## Architecture

### Layer 1: AKS Platform Registration (`modules/aks/`)

Refactor `modules/aks/meshstack_integration.tf` into a callable Terraform module that:
1. Calls `meshcloud/meshplatform/aks` (HashiCorp registry) — creates replicator SP + k8s service accounts
2. Creates `meshstack_platform.aks` — wires SP credentials and tokens into platform config
3. Creates `meshstack_landingzone.aks_default` — standard AKS role mappings

All three codebases currently use `meshcloud/meshplatform/aks` independently:
- Hub: `source = "meshcloud/meshplatform/aks"` version `~> 0.2.0`
- Meshkube: `source = "meshcloud/meshplatform/aks"` version `0.2.0`
- LCF: `source = "git::https://github.com/meshcloud/terraform-aks-meshplatform.git?ref=88fc6ed..."`

The meshplatform outputs (`replicator_service_principal`, `replicator_token`, `metering_token`)
are only consumed internally to configure the `meshstack_platform` resource — no caller needs
them as external outputs. This makes the module fully self-contained.

#### Variable layout (`modules/aks/`)

Two variables cleanly separate infrastructure from meshStack registration:

```hcl
variable "aks" {
  description = "AKS cluster infrastructure and service principal configuration."
  type = object({
    # Cluster connection
    base_url        = string
    subscription_id = string
    cluster_name    = string
    resource_group  = string

    # meshcloud/meshplatform/aks module config
    service_principal_name                = string
    namespace                             = optional(string, "meshcloud")
    create_password                       = optional(bool, false)
    workload_identity_federation          = optional(object({ issuer = string, access_subject = string }))
    replicator_enabled                    = optional(bool, true)
    replicator_additional_rules           = optional(list(object({
      api_groups = list(string), resources = list(string), verbs = list(string),
      resource_names = optional(list(string)), non_resource_urls = optional(list(string))
    })), [])
    existing_clusterrole_name_replicator  = optional(string, "")
    kubernetes_name_suffix_replicator     = optional(string, "")
    metering_enabled                      = optional(bool, true)
    metering_additional_rules             = optional(list(object({
      api_groups = list(string), resources = list(string), verbs = list(string),
      resource_names = optional(list(string)), non_resource_urls = optional(list(string))
    })), [])
  })
}

variable "meshstack_platform" {
  description = "meshStack platform and landing zone registration."
  type = object({
    owning_workspace_identifier = string
    platform_identifier         = string
    location_identifier         = optional(string, "global")

    # Display
    display_name = optional(string, "AKS Namespace")
    description  = optional(string, "Azure Kubernetes Service (AKS). Create a k8s namespace in our AKS cluster.")

    # Replication behavior
    disable_ssl_validation     = optional(bool, true)
    group_name_pattern         = optional(string, "aks-#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}")
    namespace_name_pattern     = optional(string, "#{workspaceIdentifier}-#{projectIdentifier}")
    user_lookup_strategy       = optional(string, "UserByMailLookupStrategy")
    send_azure_invitation_mail = optional(bool, false)

    # Landing zone
    landing_zone = optional(object({
      name                         = optional(string)  # defaults to "${platform_identifier}-default"
      display_name                 = optional(string, "AKS Default")
      description                  = optional(string, "Default AKS landing zone")
      automate_deletion_approval   = optional(bool, true)
      automate_deletion_replication = optional(bool, true)
      kubernetes_role_mappings     = optional(list(object({
        platform_roles   = list(string)
        project_role_ref = object({ name = string })
      })), [
        { platform_roles = ["admin"], project_role_ref = { name = "admin" } },
        { platform_roles = ["edit"],  project_role_ref = { name = "user" } },
        { platform_roles = ["view"],  project_role_ref = { name = "reader" } }
      ])
    }), {})
  })
}
```

#### Outputs (`modules/aks/`)

```hcl
output "aks" {
  description = "AKS platform identifiers for use as var.aks in the starterkit."
  value = {
    full_platform_identifier     = "${meshstack_platform.aks.metadata.name}.${var.meshstack_platform.location_identifier}"
    landing_zone_dev_identifier  = meshstack_landingzone.aks_default.metadata.name
    landing_zone_prod_identifier = meshstack_landingzone.aks_default.metadata.name
  }
}
```

Callers with separate dev/prod LZs can ignore this output and construct `var.aks` manually.

#### Caller example — meshkube

```hcl
module "aks_platform" {
  source = "github.com/meshcloud/meshstack-hub//modules/aks?ref=${var.hub.git_ref}"

  aks = {
    base_url                             = "https://dev-oug61sf3.hcp.germanywestcentral.azmk8s.io:443"
    subscription_id                      = "7490f509-..."
    cluster_name                         = "aks"
    resource_group                       = "aks-rg"
    service_principal_name               = "aks_replicator.${var.domain}"
    existing_clusterrole_name_replicator = "meshfed-service"
    kubernetes_name_suffix_replicator    = var.name
    namespace                            = var.name
    metering_enabled                     = false
    workload_identity_federation         = { issuer = var.workload_identity_issuer, access_subject = "..." }
  }

  meshstack_platform = {
    owning_workspace_identifier = meshstack_workspace.meshcloud.metadata.name
    platform_identifier         = "aks-ns"
    group_name_pattern          = "aks-${var.name}-#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}"
    namespace_name_pattern      = "${var.name}-#{workspaceIdentifier}-#{projectIdentifier}"
  }
}

# Then pass to starterkit:
module "aks_starterkit" {
  source    = "github.com/meshcloud/meshstack-hub//modules/aks/starterkit?ref=${var.hub.git_ref}"
  hub       = var.hub
  meshstack = { owning_workspace_identifier = meshstack_workspace.meshcloud.metadata.name }
  aks       = module.aks_platform.aks  # direct pass-through
  github    = var.github
}
```

### Layer 2: Constituent Building Block Definitions

Each constituent hub module gets its own `meshstack_integration.tf` (registering ONE BBD, following hub conventions). The starterkit `meshstack_integration.tf` calls them as Terraform module blocks (using relative paths — so they naturally track the same git ref as the hub checkout) and creates only the starterkit composition BBD itself.

```
modules/github/repository/
  buildingblock/              # existing
  meshstack_integration.tf    # NEW — single-file module: variables + terraform{} + resource + outputs

modules/aks/github-connector/
  backplane/, buildingblock/  # existing (stays in place)
  meshstack_integration.tf    # NEW — single-file module

modules/azure/postgresql/
  backplane/, buildingblock/  # existing
  meshstack_integration.tf    # NEW — single-file module
```

### Layer 3: Starterkit Composition (`modules/aks/starterkit/`)

```
modules/aks/starterkit/
  backplane/              # UNCHANGED (stays as-is: README.md + permissions.png)
  buildingblock/          # existing
  meshstack_integration.tf  # REWRITTEN: single-file module with 3 sub-module calls + 1 BBD (composition)
```

#### `meshstack_integration.tf` pattern:
```hcl
module "github_repo_bbd" {
  source    = "../../github/repository"   # relative path → same git ref as hub checkout
  hub       = var.hub
  meshstack = var.meshstack
  github    = { org = var.github.org, app_id = ..., ... }
}

module "github_connector_bbd" {
  source    = "../github-connector"
  hub       = var.hub
  meshstack = var.meshstack
  github    = var.github
}

module "postgresql_bbd" {
  count     = var.postgresql != null ? 1 : 0
  source    = "../../azure/postgresql"
  hub       = var.hub
  meshstack = var.meshstack
}

resource "meshstack_building_block_definition" "aks_starterkit" {
  # THE ONLY BBD resource — the composition
  version_spec = {
    implementation.terraform.ref_name = var.hub.git_ref
    inputs = {
      github_repo_definition_version_uuid = {
        argument = jsonencode(module.github_repo_bbd.bbd_version_uuid)
        assignment_type = "STATIC"
        ...
      }
      # etc.
    }
  }
}
```

**Note on module sources**: Terraform `source` cannot interpolate variables. Using relative paths is correct: when a caller sources the hub at a specific git ref (e.g., `github.com/meshcloud/meshstack-hub//modules/aks/starterkit?ref=v1.2.3`), the relative sub-module paths resolve within the same checkout. The `ref_name` field in `meshstack_building_block_definition` uses `var.hub.git_ref` to tell meshStack which ref to run buildingblocks from.

#### Variable Structure (starterkit integration)

```hcl
variable "hub" {
  type    = object({ git_ref = string })
  default = { git_ref = "main" }
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch."
}

variable "meshstack" {
  type = object({ owning_workspace_identifier = string })
  description = "Shared meshStack context passed down from the IaC runtime."
}

variable "aks" {
  description = "AKS platform identifiers. Can be passed from module.aks_platform.aks output."
  type = object({
    full_platform_identifier     = string
    landing_zone_dev_identifier  = string
    landing_zone_prod_identifier = string
  })
}

variable "github" {
  type = object({
    org                        = string
    app_id                     = string
    app_installation_id        = string
    app_pem_file               = string
    connector_config_tf_base64 = string
  })
  sensitive = true
}

variable "postgresql" {
  description = "When non-null, registers the azure/postgresql BBD. Omit/null for meshkube."
  type        = object({})
  default     = null
}
```

## Todos

### Hub — refactor platform-level integration

| ID | Description |
|----|-------------|
| `hub-refactor-aks-platform` | Refactor `modules/aks/meshstack_integration.tf` into a callable module. Remove provider blocks, convert locals to `variable "aks"` (infrastructure) and `variable "meshstack_platform"` (registration). Add `variables.tf` + `versions.tf` + `outputs.tf`. Integrate `meshcloud/meshplatform/aks` call. Output `aks` object matching `var.aks` shape of starterkit. |

### Hub — new integration files for constituent modules

| ID | Description |
|----|-------------|
| `hub-github-repo-integration` | Create `modules/github/repository/meshstack_integration.tf` + supporting files. Registers github/repository BBD with `ref_name = var.hub.git_ref`. |
| `hub-github-connector-integration` | Create `modules/aks/github-connector/meshstack_integration.tf` + supporting files. Registers github-connector BBD. |
| `hub-postgresql-integration` | Create `modules/azure/postgresql/meshstack_integration.tf` + supporting files. Registers azure/postgresql BBD. |

### Hub — starterkit integration rewrite

| ID | Depends on |
|----|------------|
| `hub-starterkit-variables` | — |
| `hub-rewrite-integration` | all 3 integration modules + hub-starterkit-variables |
| `hub-starterkit-outputs` | hub-rewrite-integration |
| `hub-starterkit-versions` | hub-rewrite-integration |

### Meshkube

| ID | Description | Depends on |
|----|-------------|-----------|
| `meshkube-add-hub-var` | Add `variable "hub"` to meshkube `variables.tf`. | — |
| `meshkube-refactor` | Remove `bbd_aks_starterkit.tf`, `bbd_github_repo.tf`, `bbd_github_actions_connector.tf`. Replace `platform_integration.tf` contents with `module "aks_platform"` call (sourcing hub `modules/aks/`) + `module "aks_starterkit"` call (sourcing hub `modules/aks/starterkit/`). Map `var.github` to new shape. Add `moved` blocks for state migration. | hub-refactor-aks-platform, hub-rewrite-integration, meshkube-add-hub-var |

### LCF

| ID | Description | Depends on |
|----|-------------|-----------|
| `lcf-add-starterkit-integration` | Create `kit/aks/buildingblocks/aks-starterkit-composition/meshstack_integration.tf` + `variables.tf` sourcing hub module with `postgresql` enabled. Add `terragrunt.hcl` in `foundations/likvid-prod/platforms/aks/buildingblocks/aks-starterkit/`. | hub-rewrite-integration |
| `lcf-add-azure-postgres-backplane` | Add `foundations/.../platforms/aks/buildingblocks/azure-postgresql/backplane/terragrunt.hcl` sourcing hub `modules/azure/postgresql/backplane`. | lcf-add-starterkit-integration |

### Single-file module convention

Each `meshstack_integration.tf` is a self-contained single-file Terraform module. Variables,
`terraform {}`, locals, resources, and outputs all in one file — no separate `variables.tf`,
`outputs.tf`, or `versions.tf`. This was chosen for simplicity since these are integration
wiring modules, not complex infrastructure.

### Logos / symbols

Each BBD resource sets `symbol = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")`.
This uses the `meshcloud/meshstack` provider function (requires `>= 0.19.3`) to load the
`logo.png` already present in each buildingblock directory. Callers no longer need to manage
logo assets separately — they come from the hub.

## Notes

- `modules/aks/github-connector/` stays in its current location (already part of hub, no move needed).
- The starterkit backplane stays as-is (README.md + permissions.png). The `meshstack_landingzone` is a platform-level concern — it already exists in `modules/aks/meshstack_integration.tf` and in meshkube's `platform_integration.tf`. The starterkit takes LZ identifiers as inputs.
- `modules/azure/aks/` (AKS cluster provisioning building block) is orthogonal to the starterkit — no changes needed for this work.
- meshplatform outputs (`replicator_service_principal`, `replicator_token`, `metering_token`) are consumed internally by `meshstack_platform` config — no caller needs them as external outputs.
- Meshkube state migration: `moved` blocks needed for `meshstack_platform.aks`, `meshstack_landingzone.aks`, `meshstack_building_block_definition.aks_starterkit[0]`, `github_repo[0]`, `github_actions_connector[0]` → new `module.aks_platform.*` / `module.aks_starterkit.*` addresses.
- LCF's `kit/aks/buildingblocks/aks-starterkit-composition/starterkit/` copy with hardcoded UUIDs becomes obsolete — removal is a follow-up, out of scope.
- LCF's `kit/aks/meshplatform/` currently only calls the meshplatform terraform module. It could be replaced with the hub's `modules/aks/` module to also manage the `meshstack_platform` and `meshstack_landingzone` resources via IaC — this is a follow-up opportunity.
- Provider blocks must NOT appear in any `meshstack_integration.tf` per hub conventions. Callers must configure `meshstack`, `azuread`, `azurerm`, `kubernetes` providers themselves.
