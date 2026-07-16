---
description: Core OpenTofu coding conventions for meshstack-hub Terraform code — always develop and validate against OpenTofu (not Terraform), and prefer the `lifecycle.enabled` meta-argument over `count = condition ? 1 : 0` for conditionally creating a single resource instance.
---

# Terraform / OpenTofu Conventions

## Always Use OpenTofu

meshstack-hub modules target **OpenTofu**, not HashiCorp Terraform. Use the `tofu` CLI locally
(`tofu validate`, `tofu test`, `tofu fmt`) instead of `terraform`. This isn't just a CLI swap —
conventions elsewhere in this repo depend on OpenTofu-specific features, e.g. `const = true` on
`variable "hub"` for static evaluation at `init` time (AGENTS.md § Shared Variable Conventions)
and `lifecycle.enabled` below.

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
