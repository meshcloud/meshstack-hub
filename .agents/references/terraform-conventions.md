---
description: Core OpenTofu coding conventions for meshstack-hub HCL — always develop and validate against OpenTofu (not Terraform), prefer the `lifecycle.enabled` meta-argument over `count = condition ? 1 : 0`, `snake_case` variable naming, provider version constraints that float inside one major, and commenting what every `try` swallows.
---

# Terraform / OpenTofu Conventions

## Always Use OpenTofu

meshstack-hub modules target **OpenTofu**, not HashiCorp Terraform. Use the `tofu` CLI locally
(`tofu validate`, `tofu test`, `tofu fmt`) instead of `terraform`. This isn't just a CLI swap —
conventions elsewhere in this repo depend on OpenTofu-specific features, e.g. `const = true` on
`variable "hub"` for static evaluation at `init` time ([meshstack-integration.md § Shared Variable Conventions](meshstack-integration.md#shared-variable-conventions))
and `lifecycle.enabled` below.

Which OpenTofu a module actually gets at run time is set by its building block definition's
`terraform_version` — see [meshstack-integration.md § Runtime version](meshstack-integration.md#runtime-version-terraform_version). Features used here must exist in the version
pinned there.

## Prefer `lifecycle.enabled` Over `count = condition ? 1 : 0`

OpenTofu >= 1.11.0 supports a `lifecycle { enabled = <bool> }` meta-argument that conditionally
creates or removes a single resource instance without going through a list-like `count` index.

Avoid:

```hcl
resource "aws_iam_openid_connect_provider" "backplane" {
  count = var.create_oidc_provider ? 1 : 0

  url            = var.workload_identity_federation.issuer
  client_id_list = [var.workload_identity_federation.audience]
}

# every reference needs a [0] index and a try() fallback against the data-source counterpart
locals {
  oidc_provider_arn = try(aws_iam_openid_connect_provider.backplane[0].arn, ...)
}
```

Prefer:

```hcl
resource "aws_iam_openid_connect_provider" "backplane" {
  lifecycle {
    enabled = var.create_oidc_provider
  }

  url            = var.workload_identity_federation.issuer
  client_id_list = [var.workload_identity_federation.audience]
}

# stable address — no [0] index, no try()/coalesce() fallback needed
locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.backplane.arn
}
```

`lifecycle.enabled` keeps the resource's address stable regardless of the condition, so code
referencing it elsewhere doesn't need `[0]` indexing or a `try()`/`coalesce()` fallback between a
"created" and "not created" resource/data-source pair.

This applies to the "0 or 1" conditional-resource idiom only — not to genuine collections where
`count`/`for_each` intentionally produce more than one instance. Existing `count = condition ? 1 : 0`
examples elsewhere in this repo (e.g. `.agents/references/aws-backplane.md`) are not being
retrofitted as part of introducing this convention; apply `lifecycle.enabled` going forward.

<!-- scorecard-checks: provider_pinned -->
## Variable Conventions

- Always use `snake_case` for variable names: `monthly_budget_amount`, not `monthlyBudgetAmount`
- **Cloud-provider-specific variables** in `meshstack_integration.tf` must be **flat** (not grouped into a single object) and prefixed with the cloud provider name: `azure_tenant_id`, `aws_region`, `gcp_project_id`, `stackit_project_id`
- **Cross-cutting concerns** like workload identity federation settings may be grouped into an `object({})` typed variable (e.g. `variable "workload_identity"`) when the fields are logically inseparable
- Only `variable "meshstack"` and `variable "hub"` use shared `object({})` conventions across all integrations
- Every provider constraint floats inside one major: `version = ">= 4.65.0, < 5.0.0"`. Never `~>`, never an exact pin. This holds for **every** `required_providers` block in the module — both tiers (`backplane/` and `buildingblock/`, including nested submodules) and `meshstack_integration.tf`, in whichever file declares them (`versions.tf`, `provider.tf`, …).
  The floor stays loose so a root configuration that combines several hub modules resolves one version for all of them; a pin in either tier caps the whole configuration, which is how `modules/meshstack/noop` capped the e2e suite. The ceiling keeps a bare `>=` from taking the next major on the next `init`, which is how azurerm 5.0 reached buildingblock code written for 4.x. Strict pinning belongs to root configurations (ICF/LCF) via `.terraform.lock.hcl`.
  `meshcloud/meshstack` is the exception and keeps a bare `>=`: it is still on 0.x, where breaking changes ride on a minor release, so `< 1.0.0` would protect nothing. The scorecard exempts it.
- Terraform baseline: `>= 1.12.0` to cover OpenTofu v1.12.0 with `const` variable support (requires OpenTofu ≥ 1.12 or Terraform ≥ 1.15)

<!-- scorecard-checks: try_explained -->
## Guarding Expressions with `try`

`try` swallows every error its expression can raise, including the typo. Each one carries a comment
saying what it swallows and why that is the right answer:

```hcl
locals {
  # `try` so that a run which produced no outputs at all fails on the status assertion, which says
  # what went wrong, rather than on evaluating this.
  resolved_tags = try(jsondecode(meshstack_building_block.this.status.outputs["tags"].value), {})
}
```

The comment sits directly above the `try`, or above the attribute that owns the expression when the
`try` is nested inside it. Prefer not needing it: a variable default, `optional()` or an explicit
`null` check says the same thing without hiding the next error too.

