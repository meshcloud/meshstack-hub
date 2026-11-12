# Runner identity (shared)

Looks up the building block runner of a definition and returns what the definition and its backplane
need for workload identity federation: the runner's `ref`, the token path, the issuer and the
audience.

It also returns `identities`: one identity per runner the backplane trusts. A building block keeps
running on the definition version it was created with. After a definition moves to another runner,
building blocks on older versions still present the identity of the old runner. List the old runner
in `trusted_runner_refs` until every building block uses a version on the new runner.

The module fails when a runner offers no token for `cloud`.

See [Runner identity](../../../.agents/references/meshstack-integration.md#runner-identity) for why
a definition pins the runner it looks up.

## Usage

```hcl
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud               = "aws"
  runner_ref          = var.meshstack.runner_ref
  trusted_runner_refs = var.meshstack.trusted_runner_refs
  versions            = meshstack_building_block_definition.this.versions
}

module "backplane" {
  # ...
  runner_identities = module.runner.identities
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

The definition reads `ref` and `token_path`, and the module reads the definition's `versions`. This
is not a cycle, because OpenTofu evaluates each input and each output of a module separately, and
only `identities` reads `versions`.

A caller whose backplane does not take `identities` yet leaves out `trusted_runner_refs` and
`versions`. It passes `issuer`, `audience` and the subject of `version_latest` to its backplane:

```hcl
module "backplane" {
  # ...
  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}
```

## Inputs

| Name | Description |
|---|---|
| `cloud` | The token the building block signs in with: `aws`, `azure` or `gcp`. A STACKIT building block uses `azure` and an OTC building block uses `gcp`, each as a generic OIDC token. |
| `runner_ref` | The runner to look up, as given in `var.meshstack.runner_ref`. Null looks up the default runner. |
| `trusted_runner_refs` | Other runners to trust besides the current one, as given in `var.meshstack.trusted_runner_refs`. Default `[]`. |
| `versions` | The `versions` of the building block definition. The module reads only `workload_identity_federation` of each version. Only `identities` reads it. Default `{}`. |

## Outputs

| Name | Description |
|---|---|
| `ref` | The `ref` of the looked-up runner, for `version_spec.runner_ref`. |
| `token_path` | The path where the runner writes the token for `cloud`. |
| `issuer` | The issuer of the runner's tokens. |
| `audience` | The audience of the runner's token for `cloud`. |
| `identities` | A list with one `{ issuer, audience, subject }` per runner to trust. The current runner comes first, then each runner of `trusted_runner_refs`. |

## How `identities` finds the subject of a runner

A version of a definition has the issuer, the audience and the subject that its runs present, but
not the runner. So a version counts as running on a runner when it has the issuer and the audience
of that runner. The subject of the runner is the subject of those versions.

- `subject` is null when no version runs on the runner. A backplane skips such an entry.
- `subject` is unknown in a plan that creates the definition or changes its runner. The list itself
  has a known length, because it has one entry per runner.
- A trusted runner that is also the current runner appears once.
- The module fails when two of the runners share issuer and audience but not the subject template,
  because the versions of the two can't be told apart.

## Required permissions

The API key that applies the calling module needs `BUILDINGBLOCKRUNNER_LIST`. Without it, the
lookup reports that no runner matches.
