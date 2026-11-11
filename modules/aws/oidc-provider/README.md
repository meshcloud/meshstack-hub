# meshStack OIDC Provider (shared)

Registers the meshStack building block runner's token issuer as an IAM OIDC provider so that AWS
backplanes in this account can trust it.

**Apply this once per issuer in each AWS account that hosts building block backplanes.** AWS
registers one OIDC provider per issuer URL per account, so this cannot belong to an individual
backplane: the second backplane to try would fail with `EntityAlreadyExists`, and destroying
whichever owned it would break every other backplane in the account. A backplane looks the provider
up by its issuer, so it needs no value from this module, but the provider must exist before the
backplane is planned.

See [the shared OIDC provider](../../../.agents/references/aws-backplane.md#the-shared-oidc-provider)
for the full rationale and for how to migrate an account whose provider is still owned by a
backplane's state.

## Usage

```hcl
provider "aws" {
  region = "eu-central-1"
}

# A null uuid looks up the default runner.
data "meshstack_building_block_runner" "this" {
  metadata = {
    uuid = "<runner uuid>"
  }
}

module "meshstack_oidc_provider" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/oidc-provider?ref=main"

  workload_identity_federation = {
    issuer    = data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer
    audiences = [data.meshstack_building_block_runner.this.spec.workload_identity_federation.aws.audience]
  }
}

# Then, per building block definition:
module "s3_bucket" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/s3_bucket?ref=main"

  # Only when the same root module applies both: the backplane looks the provider up while it plans.
  depends_on = [module.meshstack_oidc_provider]

  meshstack = {
    # ...
    runner_ref = data.meshstack_building_block_runner.this.ref
  }
  # ...
}
```

Before a definition moves to a runner with another issuer, apply this module a second time for the
new issuer, and list the old runner in `meshstack.trusted_runner_refs` of the building block module.

The `meshstack_building_block_runner` data source can be used to look up issuer and audience (`spec.workload_identity_federation.issuer` and `spec.workload_identity_federation.aws.audience`) for specific runners. Since AWS allows only one OIDC provider per issuer and account multiple runners that use the same issuer must share an OIDC provider by adding all audience values to the list.
For a self-hosted runner make sure to pass a matching runner ref as `meshstack.runner_ref` to every building block module that uses a federated identity.

The issuer URL has to be reachable from where the building block runs to check the thumbprint.

## Required permissions

The identity applying this needs `iam:CreateOpenIDConnectProvider`, `iam:GetOpenIDConnectProvider` and `iam:TagOpenIDConnectProvider` in the target account.
