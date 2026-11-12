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
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
  })
  description = "Shared meshStack context, see docs."
}
```

Use both in the building block definition. Always forward `var.meshstack.tags` to `metadata.tags` so
workspace-level tags propagate to the definition, `var.hub.bbd_draft` to the `draft` field of
`version_spec`, and `var.meshstack.runner_ref` to `version_spec.runner_ref` and to the `runner_ref`
of any `meshstack_integration` config the definition uses, which meshStack encrypts its secrets for.
A definition with workload identity federation pins the looked-up runner instead, see
[Runner identity](#runner-identity).

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

## Adding an Input to an Existing Definition

meshStack stops every existing building block of the definition in `WAITING_FOR_USER_INPUT` when
the definition gains a required input, even one with a default. So a new input is either
`is_optional = true`, or every caller always sets it and it is `updateable_by_consumer = true`;
without that flag, setting it on an existing block fails with 403 "You tried to edit input ...".
A BOOLEAN input cannot be optional, so it always takes the second way.

<!-- scorecard-checks: bbd_supported_platforms -->
## Supported Platforms

A `TENANT_LEVEL` definition takes `spec.supported_platforms` from `var.meshstack.supported_platforms`,
so a consumer can narrow it to one platform or landing zone by passing that object's `ref`. The
default is what the module supports, normally one platform type:

```hcl
variable "meshstack" {
  type = object({
    # ...
    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })), [{ name = "AZURE" }])
  })
}

resource "meshstack_building_block_definition" "this" {
  spec = {
    target_type         = "TENANT_LEVEL"
    supported_platforms = var.meshstack.supported_platforms
  }
}
```

A definition with `use_in_landing_zones_only = true` keeps a fixed `supported_platforms`, because
only landing zones and compositions order it.
A `WORKSPACE_LEVEL` definition sets no `supported_platforms`; meshStack rejects even an empty set.

A platform needs meshStack 2026.40.0 or later, a landing zone 2026.45.0 and meshstack provider
0.28.0.

<!-- scorecard-checks: bbd_structured_inputs, bbd_input_order, bbd_input_defaults -->
## Input Types, Order and Defaults

meshStack passes each input to the Terraform variable of the same name.

- An input whose variable is an `object` or a `map` is `type = "JSON"` with a `json_schema`: meshPanel
  renders a form from the schema, and meshStack rejects a value the schema does not allow. `CODE`
  stays right for free text such as YAML, HCL or a script.
- Declare the inputs by ascending `display_order`, and the `buildingblock/` variables they feed in
  the same order, so the code reads like the order form. Inputs meshStack fills in, such as the
  workspace identifier, come after those a person sets, and the STATIC `hub` comes last.
- The definition owns every value, so a `buildingblock/` variable fed by a required input has no
  `default` and is `nullable = false`. A `const = true` variable keeps a default, because `tofu init`
  and `validate` outside a run need it.
- An input with a sane default is required and carries it in `default_value`. A JSON object input
  also puts each field's default into its schema as `default`, because the order form shows only
  those; derive both from one local.
- `is_optional = true` is for a value that is really absent, with no sane default. The code checks
  only for null. Handling `""` as unset hides that contract. The check finds `coalesce(var.x, "")`,
  `var.x == ""`, `var.x != ""` and `compact([var.x])`, and misses the same handling through a local.
- meshStack currently sends no value for an input whose value is null, whether it is optional or
  hidden by a `condition`. So the variable of an optional or conditional input has `default = null`.

<!-- scorecard-checks: wif_no_replicator -->
## Runner identity

A building block run presents an identity a cloud backplane has to trust. The runner declares the
issuer, the per-cloud audience and token path, and the subject scheme. meshStack resolves the
subject per definition. The module never builds any of them from strings.

A definition can't read its own `version_latest` for an input, and the token path is one. So every
definition with workload identity federation looks its runner up and pins itself to it. The lookup
then describes the runner every run uses, also when `var.meshstack.runner_ref` is null.

```hcl
# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
data "meshstack_building_block_runner" "this" {
  metadata = {
    uuid = var.meshstack.runner_ref == null ? null : var.meshstack.runner_ref.uuid
  }

  lifecycle {
    postcondition {
      # try: a runner without any workload identity federation has a null spec.workload_identity_federation.
      condition     = try(self.spec.workload_identity_federation.<cloud>, null) != null
      error_message = "The building block runner offers no token for <Cloud>. Pick a runner that offers one via var.meshstack.runner_ref."
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    runner_ref = data.meshstack_building_block_runner.this.ref
    inputs = {
      # the cloud's token file env var, e.g. ARM_OIDC_TOKEN_FILE_PATH or AWS_WEB_IDENTITY_TOKEN_FILE
      <TOKEN_FILE_ENV> = {
        # ...
        argument = jsonencode(data.meshstack_building_block_runner.this.spec.workload_identity_federation.<cloud>.token_path)
      }
    }
  }
}

module "backplane" {
  # ...
  workload_identity_federation = {
    issuer   = data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer
    audience = data.meshstack_building_block_runner.this.spec.workload_identity_federation.<cloud>.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}
```

- `<cloud>` is `aws`, `azure` or `gcp`. A cloud without its own token uses another one as a generic
  OIDC token: STACKIT the `azure` one, OTC the `gcp` one.
- `version_latest.workload_identity_federation.subject` is the runner's subject template with every
  placeholder filled in for this definition. It is the only place a subject comes from, and it is
  known after apply, exactly as `metadata.uuid` already was.
- Leave `var.meshstack.runner_ref` null and the definition runs on the default runner. Pass the `ref` of a `meshstack_building_block_runner`; `kind` is required so that nobody
  builds the object by hand.
- A definition applied with an ephemeral API key, as in a reference architecture, needs the
  `BUILDINGBLOCKRUNNER_LIST` permission. Without it the data source reports that no runner matches.
- The subject is known after apply. Where the definition consumes a backplane output that depends
  on the same input, split the input; GCP does, see
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
