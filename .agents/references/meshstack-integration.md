---
description: Conventions for meshstack_integration.tf in meshstack-hub modules — file structure and variable ordering, the shared `hub` and `meshstack` variables, pinning module sources and BBD `ref_name` to `var.hub.git_ref`, the required meshcloud/meshstack provider, the BBD `terraform_version`, and the `building_block_definition` output.
---

<!-- scorecard-checks: meshstack_integration, backplane_source_hub_git_ref, ref_name_hub_git_ref -->
# `meshstack_integration.tf` Conventions

These files are examples showing how to integrate building block and platform modules with a meshStack instance.
They are starting points that should cover the simplest use case.
A secondary purpose of these files is to serve as a ready-to-use Terraform module root that a foundation repository can source directly.

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
## Required providers

Every `meshstack_integration.tf` must declare the `meshcloud/meshstack` provider in a
`required_providers` block, with a bare `>=` constraint (e.g. `>= 0.20.0`) — it is the one
provider exempt from the upper bound under [terraform-conventions.md § Variable Conventions](terraform-conventions.md#variable-conventions).

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

<!-- scorecard-checks: bbd_terraform_version_floor -->
## Runtime version (`terraform_version`)

`version_spec.implementation.terraform.terraform_version` selects the binary the building block
runner downloads and executes. Despite the name it is **not always Terraform**: the runner routes
`<= 1.5.5` to a HashiCorp Terraform release and anything **above 1.5.5 to the matching OpenTofu
release**. Every hub module is therefore an OpenTofu module, and any published OpenTofu version is
selectable — meshStack applies no allow-list and has no default (the field is required).

**Pin `1.12.5` in new modules.** Two reasons not to go lower:

- OpenTofu only started short-circuiting `&&` and `||` in **1.10.0**. Below that, a guard like
  `var.x == null || var.x.attr == "y"` evaluates the right operand against a `null` and faults at
  run time. `tofu validate`, `tofu fmt` and the scorecard all miss this — only a real building
  block run surfaces it.
- 1.12.x matches the OpenTofu the repo's own toolchain provides, so `tofu test` locally exercises
  the same engine a building block run will.

The meshStack panel prefills `1.9.0` when you create a definition through the UI. Do not carry that
value into a hub module.

The scorecard enforces a floor of `1.12.0` rather than an exact value, and reports `➖` for every
implementation type that has no such field: `manual`, `github_workflows`, `gitlab_pipeline` and
`azure_devops_pipeline`. The `ref_name` check is skipped for the same types — a pipeline
implementation's `ref_name` is a branch in the customer's own repository, not a hub release.

<!-- scorecard-checks: variable_hub, variable_meshstack, bbd_draft, bbd_tags_forwarded, bbd_inputs_explicit_defaults -->
## Shared Variable Conventions

Two variables must appear in every `meshstack_integration.tf`.

`variable "hub"` determines the git reference modules are sourced from. You may extend it with
additional fields as needed (e.g. `base_url`), but `git_ref` is always required.

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

`variable "meshstack"` carries the context integrating with meshStack requires, like the workspace
that owns the resources.

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

Use both in the building block definition. Always forward `var.meshstack.tags` to `metadata.tags` so
workspace-level tags propagate to the definition, and `var.hub.bbd_draft` to the `draft` field of
`version_spec`.

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

**If a `meshstack_building_block_definition` input's `argument` field references a variable, that variable must have an explicit default** — do not rely on nested `optional()` defaults (for example via a bare `default = {}`), since some downstream consumers don't evaluate Terraform's object-attribute defaulting and would see unset fields instead. Keep the `optional()` type constraints regardless — they still document intent and protect callers who omit keys.

<!-- scorecard-checks: wif_no_replicator -->
## Runner identity

A building block run presents an identity a cloud backplane has to trust. The runner declares the
scheme once, meshStack resolves it per definition, and the module reads the result from the
definition's `version_latest`. It never builds a subject from strings.

```hcl
variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }
    # ...
  }
}

module "backplane" {
  # ...
  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}
```

- `version_latest.workload_identity_federation.subject` is the runner's subject template with every
  placeholder filled in for this definition. It is the only place a subject comes from, and it is
  known after apply, exactly as `metadata.uuid` already was.
- `issuer` and the per-cloud `audience` describe the runner, and the definition reports them for the
  runner its latest version runs on. AWS reads `.aws.audience`, GCP `.gcp.audience`;
  Azure and STACKIT need none. A self-hosted runner declares its own values, so never hardcode them.
- `building_block_runner_uuid` feeds `version_spec.runner_ref`, and the status follows it, so the
  backplane always trusts the runner the definition actually runs on. Omit it and the definition
  runs on the shared runner meshStack hosts.
- The whole status is known after apply. Where the definition consumes a backplane output that
  depends on the same input, split the input; GCP does, see
  [gcp-backplane.md](gcp-backplane.md#keeping-the-subject-out-of-the-credentials).

`data.meshstack_integrations.….workload_identity_federation.replicator` is **not** a substitute.
That entry describes the replicator's own identity, and using it here only ever worked because the
runner happens to share the replicator's cluster and namespace. Platform-level
`modules/<cloud>/meshstack_integration.tf` still reads it, because it configures the replicator.

`modules/aws/oidc-provider` owns no definition, because it registers the issuer per AWS account
before any definition exists, so it takes `issuer` and the `audiences` of every runner behind it as an input instead.

**Known limitation.** The backplane trusts the identity of the version the Terraform resource
manages, which is the newest one. A building block keeps running on the version it was created
with, so moving a definition to a different runner breaks the blocks that still run on the old
version until they upgrade.

<!-- scorecard-checks: bbd_catalog_overrides -->
## Overridable Catalog Properties

`display_name`, `description` and `readme` are the catalog properties: everything a consumer sees
before ordering. A consumer that deploys the module more than once has to tell those deployments
apart — several flavours of a starterkit side by side, or an automated deployment that marks its
definitions as its own so nobody mistakes them for the real catalog. So all three are overridable,
with the module's own text as the default:

```hcl
variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

resource "meshstack_building_block_definition" "this" {
  spec = {
    display_name = coalesce(var.bbd_display_name, "STACKIT Storage Bucket")
    description  = coalesce(var.bbd_description, "Provisions an S3-compatible bucket.")
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      ...
    EOT
    ))
  }
}
```

A module that also registers a `meshstack_integration` makes its display name overridable the same
way, as `integration_display_name`.


<!-- scorecard-checks: output_bbd -->
## Exposing Building Block Definition References

When a `meshstack_integration.tf` exposes building block definition references for compositions, use a single object output named `building_block_definition`:

```hcl
output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}
```

---

Related: [meshstack-resources.md](meshstack-resources.md) for the meshStack provider resources an
integration declares, [module-layout.md](module-layout.md) for where the file sits in a module, and
[terraform-conventions.md](terraform-conventions.md) for provider version ranges.
