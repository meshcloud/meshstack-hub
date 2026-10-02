---
name: Forgejo Action Variables and Secrets
supportedPlatforms:
  - stackit
description: |
  Helper module managing Forgejo Actions secrets and variables via the restapi provider.
  Needed because the Forgejo provider cannot delete secrets and does not support action variables.
---

# action-variables-and-secrets

This helper module manages Forgejo Actions **secrets** and **variables** on a
repository via the REST API (using the `restapi` provider).

## Why does this module exist?

The Forgejo Terraform provider has two limitations that prevent managing these
resources natively:

1. **Secrets** – the provider does not actually delete secrets on `destroy`;
   it only removes them from state.
2. **Action variables** – the provider does not support action variables at all.

By using the generic `restapi` provider with explicit `create_path`,
`update_path`, `destroy_path` and `read_path` definitions, this module can
perform real CRUD operations against the Forgejo API, including proper deletion.

> **Sunset note:** Once the upstream Forgejo Terraform provider gains full
> support for action secrets (with real delete) and action variables, this
> module should be removed and replaced with native provider resources.

## Provider configuration

The module expects **two aliased `restapi` provider configurations** passed from
the caller:

| Alias                     | `write_returns_object` | Reason |
|---------------------------|------------------------|--------|
| `restapi.action_variable` | `true`                 | Variables can be read back after write. |
| `restapi.action_secret`   | `false`                | Secrets cannot be read back (Forgejo returns empty). |

Both providers must point at the Forgejo host with an appropriate API token.

## Usage

```hcl
module "action_variables_and_secrets" {
  source = "./action-variables-and-secrets"
  providers = {
    restapi.action_variable = restapi.action_variable
    restapi.action_secret   = restapi.action_secret
  }

  repository_id    = forgejo_repository.this.id
  action_variables = var.action_variables
  action_secrets   = var.action_secrets
}
```
