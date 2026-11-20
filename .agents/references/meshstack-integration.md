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
    # See "Trusted runners".
    additional_trusted_runner_refs = optional(list(object({
      kind = string
      uuid = string
    })), [])
  })
  description = "Shared meshStack context, see docs."
}
```

The description of `variable "meshstack"` is always exactly `Shared meshStack context, see docs.`,
whatever fields a module adds. The docs are
[meshStack integration variables](../../skills/meshstack-hub/SKILL.md#meshstack-integration-variables),
which the hub website links from its setup steps. A new field gets an entry there.

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

Landing-zone-only definitions follow the same rule. A default that depends on another input, such
as the platform type a module registers, comes from
`coalesce(var.meshstack.supported_platforms, [{ kind = null, name = ..., uuid = null }])` instead.
A module with no natural default, such as one for any Kubernetes cluster, makes the field required.
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
`modules/meshstack/runner-identity` is the one place that does the lookup. It fails when the runner
has no workload identity federation settings for `cloud`.

```hcl
# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud      = "<cloud>"
  runner_ref = var.meshstack.runner_ref
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    runner_ref = module.runner.ref
    inputs = {
      # the cloud's token file env var, e.g. ARM_OIDC_TOKEN_FILE_PATH or AWS_WEB_IDENTITY_TOKEN_FILE
      <TOKEN_FILE_ENV> = {
        # ...
        argument = jsonencode(module.runner.token_path)
      }
    }
  }
}

module "backplane" {
  # ...
  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}
```

- `<cloud>` is `aws`, `azure` or `gcp`. A cloud without its own token uses another one as a generic
  OIDC token: STACKIT the `azure` one, OTC the `gcp` one.
- `version_latest.workload_identity_federation.subject` is the runner's subject template with every
  placeholder filled in for this definition.
- Leave `var.meshstack.runner_ref` null and the definition runs on the default runner. Pass the `ref` of a `meshstack_building_block_runner`; `kind` is required so that nobody
  builds the object by hand.
- A definition applied with an ephemeral API key, as in a reference architecture, needs the
  `BUILDINGBLOCKRUNNER_LIST` permission. Without it the lookup reports that no runner matches.
- The subject is known after apply. Where the definition consumes a backplane output that depends
  on the same input, split the input; GCP does, see
  [gcp-backplane.md](gcp-backplane.md#keeping-the-subject-out-of-the-credentials).

`data.meshstack_integrations.….workload_identity_federation.replicator` is **not** a substitute.
That entry describes the replicator's own identity, and using it here only ever worked because the
runner happens to share the replicator's cluster and namespace. Platform-level
`modules/<cloud>/meshstack_integration.tf` still reads it, because it configures the replicator.

`modules/aws/oidc-provider` owns no definition, because it registers the issuer per AWS account
before any definition exists, so it takes `issuer` and the `audiences` of every runner behind it as an input instead.

A module with this wiring configures the cloud for the tokens of the latest version only. But
meshStack runs a building block with the definition version it was created with, until someone
upgrades it. So after a new version uses another runner, the cloud rejects the tokens of building
blocks on older versions. A module adds the wiring in [Trusted runners](#trusted-runners) to avoid
this.

### Trusted runners

meshStack runs a building block with the definition version it was created with, until someone
upgrades it. Nobody can change the runner of a released version. So after a new version uses
another runner, building blocks on older versions still run on the old runner. Their tokens still
contain the issuer and the subject that belong to the old runner. The cloud rejects these tokens if
the backplane configured it for the latest version only.

`meshstack.additional_trusted_runner_refs` lists more runners for the backplane. The backplane then configures
the cloud to accept the tokens of this definition from these runners too. In this file, the
*current runner* is the runner of the latest version. A *trusted runner* is a runner in that list.
The cloud still checks the subject. The subject contains the uuid of the definition if the subject
template of the runner has that placeholder. The cloud then rejects the tokens of other definitions.
A module supports this if its `meshstack` variable has `additional_trusted_runner_refs`.

The platform engineer:

1. adds the `ref` of the old runner to `meshstack.additional_trusted_runner_refs`. This happens in the apply
   that sets `meshstack.runner_ref` to the new runner, or earlier. A
   `meshstack_building_block_runner` data source returns the `ref`. If `meshstack.runner_ref` was
   null, the old runner is the default runner of meshStack at the last apply. The plan shows its
   uuid in the change of `version_spec.runner_ref`. With a null `runner_ref`, a new default runner
   in meshStack also switches the definition at the next apply.
2. removes the old runner when no building block is on a version that uses it. The building
   block table in the panel shows the version of each building block. The owner of the definition or
   an admin upgrades them there. An upgrade goes to the latest released version, so release the new
   version first.

A definition with only a draft version needs no trusted runner. meshStack changes the runner of a
draft version in place. The building blocks on the draft use the new runner in their next run.

```hcl
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud                          = "aws"
  runner_ref                     = var.meshstack.runner_ref
  additional_trusted_runner_refs = var.meshstack.additional_trusted_runner_refs
  versions                       = meshstack_building_block_definition.this.versions
}

module "backplane" {
  # ...
  runner_identities = module.runner.identities
}
```

- `module.runner.identities` has one `{ runner_uuid, issuer, audience, subject }` per runner. The
  current runner comes first, then the trusted runners, ordered by uuid. The module takes each
  subject from `versions`. So the integration does not read `version_latest` for the subject.
- A backplane resource that exists once per runner uses the runner uuid as its `for_each` key. With
  the list position as key, a switch would replace the resources of the old runner. OpenTofu must
  know the uuid during the plan. So create a runner in an earlier apply than the one that uses it.
- Two runners can have the same issuer, audience and subject template in their settings. Their
  runs then present the same token for a definition, and `identities` has one entry for both.

What a backplane does with the identities depends on the cloud:

| Cloud | The backplane takes | It creates |
|---|---|---|
| AWS | `runner_identities = module.runner.identities` | one statement per runner in the trust policy of the role |
| Azure, STACKIT | `trusted_runner_identities = module.runner.trusted_identities`, next to `workload_identity_federation` for the current runner | one federated credential per trusted runner |
| GCP, OTC | `trusted_runner_identities`, the identity of the current runner (GCP: `workload_identity_federation_trust`, OTC: `workload_identity_federation`), the uuid of the current runner and of `meshstack.original_runner_ref` | one identity provider per runner |

The module takes the subject of an entry from a version. So the entry of a trusted runner has a
null subject if no version uses the runner. The AWS backplane then omits the entry from the trust
policy and shows no message. It still looks up the OIDC provider for the issuer of the entry. The
other backplanes fail and show the uuid of the runner. They fail in the plan, or in the apply if the
same apply changes the runner.
So list a runner only for a module whose definition has a released version that uses it. Do not
pass one list to all modules.

#### `meshstack.original_runner_ref` (GCP and OTC)

On GCP and OTC the backplane creates one identity provider per runner. A static input of each
version contains the name of the identity provider for the runner of that version. On GCP this
input is `CREDENTIALS_FILE`, on OTC it is `OTC_IDENTITY_PROVIDER`. Nobody can edit a released
version. So the backplane must not rename an identity provider while a building block is on such a
version.

The *base name* is the name of the identity provider in a module without trusted runners. On GCP it
is `workload_identity.pool_identifier`, on OTC it is the `name` of the backplane.

- While `original_runner_ref` is null, the backplane gives the base name to the identity provider
  for the current runner. Every deployment is in this state before its first switch.
- With the first apply that lists a trusted runner, set `original_runner_ref` to the runner whose
  identity provider has the base name at that time. That is the runner that the definition used
  at the apply before. The backplane keeps the base name for its identity provider. For every other
  runner, the name contains the first 8 characters of the runner uuid.
- Never remove `original_runner_ref`, even after you remove the old runner from
  `additional_trusted_runner_refs`. Without it, the backplane gives the base name to the identity provider for
  the current runner. The released versions that use the current runner contain the name with the
  uuid. So the cloud rejects the tokens of their runs.
- The plan fails when the backplane gets a trusted runner and `original_runner_ref` is null.
- A wrong `original_runner_ref` gives no error. The backplane then changes the identity provider
  with the base name to another runner, and the cloud rejects the tokens of the older versions.
- The runner in `original_runner_ref` can share its entry in `identities` with another runner. Then
  keep it in `additional_trusted_runner_refs`. The integration finds the shared entry through
  `module.runner.entry_runner_uuids`.
- GCP keeps a deleted pool provider for about 30 days and refuses its id in that time. So a runner
  that you removed from `additional_trusted_runner_refs` cannot return to the list in that time.

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
