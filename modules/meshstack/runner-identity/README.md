# Runner identity (shared)

Looks up the building block runner of a definition and returns what the definition and its backplane
need for workload identity federation: the runner's `ref`, the token path, the issuer and the
audience.

It also returns `identities`. Each entry has the issuer, audience and subject of the tokens of one
runner. The list covers the runner in `runner_ref` and each runner in `additional_trusted_runner_refs`. See
[Trusted runners](../../../.agents/references/meshstack-integration.md#trusted-runners) for when a
platform engineer lists a runner there.

The plan fails when a runner has no workload identity federation settings for `cloud`.

See [Runner identity](../../../.agents/references/meshstack-integration.md#runner-identity) for why
a definition pins the runner it looks up.

## Usage

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

The definition reads `ref` and `token_path` of the module. The module reads `versions` of the
definition. OpenTofu sees no dependency cycle, because only `identities` and `trusted_identities`
depend on `versions`.

A caller whose backplane takes no `identities` leaves out `additional_trusted_runner_refs` and `versions`. It
passes `issuer`, `audience` and the subject of `version_latest` to its backplane:

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
| `cloud` | Which token the runs present: `aws`, `azure` or `gcp`. A STACKIT building block presents the `azure` token as a generic OIDC token. An OTC building block does the same with the `gcp` token. |
| `runner_ref` | The runner to look up, as given in `var.meshstack.runner_ref`. Null looks up the default runner. |
| `additional_trusted_runner_refs` | The runners in `var.meshstack.additional_trusted_runner_refs`. List a runner while a building block is on an older version that uses it. Default `[]`. |
| `versions` | The `versions` attribute of the building block definition. The module takes the subject of each entry in `identities` from it. Default `{}`. |

## Outputs

| Name | Description |
|---|---|
| `ref` | The `ref` of the looked-up runner, for `version_spec.runner_ref`. |
| `token_path` | The path where the runner writes the token for `cloud`. |
| `issuer` | The issuer of the runner's tokens. |
| `audience` | The audience of the runner's token for `cloud`. |
| `identities` | One `{ runner_uuid, issuer, audience, subject }` per runner. The runner in `runner_ref` comes first, then the runners in `additional_trusted_runner_refs`, ordered by uuid. |
| `entry_runner_uuids` | A map from the uuid of each looked-up runner to the `runner_uuid` of its entry in `identities`. The two differ for a runner that shares its entry with another runner. |
| `trusted_identities` | `identities` without its first entry. Use it if the backplane takes the runner in `runner_ref` in a separate variable. |

## How `identities` finds the subject of a runner

The `versions` attribute of the definition contains the issuer, audience and subject of each
version. It does not contain the runner. So the module matches a version to a runner by issuer and
audience. It takes the subject from the matching versions.

- The plan fails when the latest version is released and uses another runner than `runner_ref`. A
  released version cannot change its runner. Set `hub.bbd_draft = true` to create a draft version.
- `subject` is null when no version uses a trusted runner, or when the caller omits `versions`. See
  [Trusted runners](../../../.agents/references/meshstack-integration.md#trusted-runners) for what
  a backplane does with such an entry.
- Two runners with the same issuer and audience share one entry with the uuid of the first.
- Two of the runners can have the same issuer and audience but different subject templates. The
  plan then fails, because the module cannot match the versions to one of the two.

## Required permissions

The API key that applies the calling module needs `BUILDINGBLOCKRUNNER_LIST`. Without it, the
lookup reports that no runner matches.
