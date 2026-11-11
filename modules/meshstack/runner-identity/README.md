# Runner identity (shared)

Looks up the building block runner of a definition and returns what the definition and its backplane
need for workload identity federation: the runner's `ref`, the token path, the issuer and the
audience.

The module fails when the runner offers no token for `cloud`.

See [Runner identity](../../../.agents/references/meshstack-integration.md#runner-identity) for why
a definition pins the runner it looks up.

## Usage

```hcl
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud      = "aws"
  runner_ref = var.meshstack.runner_ref
}

module "backplane" {
  # ...
  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    runner_ref = module.runner.ref
    inputs = {
      AWS_WEB_IDENTITY_TOKEN_FILE = {
        # ...
        argument = jsonencode(module.runner.token_path)
      }
    }
  }
}
```

## Inputs

| Name | Description |
|---|---|
| `cloud` | The token the building block signs in with: `aws`, `azure` or `gcp`. A STACKIT building block uses `azure` and an OTC building block uses `gcp`, each as a generic OIDC token. |
| `runner_ref` | The runner to look up, as given in `var.meshstack.runner_ref`. Null looks up the default runner. |

## Outputs

| Name | Description |
|---|---|
| `ref` | The `ref` of the looked-up runner, for `version_spec.runner_ref`. |
| `token_path` | The path where the runner writes the token for `cloud`. |
| `issuer` | The issuer of the runner's tokens. |
| `audience` | The audience of the runner's token for `cloud`. |

## Required permissions

The API key that applies the calling module needs `BUILDINGBLOCKRUNNER_LIST`. Without it, the
lookup reports that no runner matches.
