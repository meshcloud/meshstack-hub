# Runner identity (shared)

This module reads two values from the runners of a building block definition: the token path of the
current runner, and one identity per runner for the backplane to trust.

A building block keeps running on the version it was created with. After a definition moves to
another runner, building blocks on older versions still present the old runner's identity. List
the old runner in `trusted_runner_refs` until all building blocks use a version on the new runner.

## Usage

```hcl
module "runner_identity" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud               = "aws"
  runner_ref          = var.meshstack.runner_ref
  trusted_runner_refs = var.meshstack.trusted_runner_refs
  versions            = meshstack_building_block_definition.this.versions
}

module "backplane" {
  # ...
  workload_identity_federations = module.runner_identity.identities
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    runner_ref = var.meshstack.runner_ref
    inputs = {
      AWS_WEB_IDENTITY_TOKEN_FILE = {
        # ...
        argument = jsonencode(module.runner_identity.token_path)
      }
    }
  }
}
```

The definition reads `token_path` and the module reads the definition's `versions`. OpenTofu
evaluates each input and output of a module separately, so the two can read from each other.

Each runner gets one identity with one `subject`. So the list has a known length at plan time, and
a backplane can use it in `for_each`. The subject of a new definition is known only after apply.
