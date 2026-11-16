# meshStack OIDC Provider (shared)

Creates the IAM OIDC provider for one issuer of meshStack building block tokens. The AWS backplanes
in this account need it. Without it, AWS rejects these tokens.

**Apply this once per issuer in each AWS account that hosts building block backplanes.** AWS
allows one OIDC provider per issuer URL per account, so a backplane cannot create it. The second
backplane would fail with `EntityAlreadyExists`. A destroy of the first backplane would delete the
provider of all others. A backplane that gets `runner_identities` looks the provider up by its
issuer URL and needs no output of this module. Apply this module before you plan a backplane.

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

  meshstack = {
    # ...
    runner_ref = data.meshstack_building_block_runner.this.ref
  }
  # ...
}
```

A backplane looks the provider up during the plan. So apply this module before the first plan of
a hub module, from its own root module or with `tofu apply -target=module.meshstack_oidc_provider`.
Do not set `depends_on` on the hub module. It makes the issuer unknown during the plan, and the
lookup then fails with "Invalid for_each argument".

A new version of a definition can use a runner with tokens from another issuer. Apply this module
once more for that issuer first. Also add the old runner to `meshstack.trusted_runner_refs` of the
hub module.

The `meshstack_building_block_runner` data source can be used to look up issuer and audience (`spec.workload_identity_federation.issuer` and `spec.workload_identity_federation.aws.audience`) for specific runners. Since AWS allows only one OIDC provider per issuer and account multiple runners that use the same issuer must share an OIDC provider by adding all audience values to the list.
For a self-hosted runner make sure to pass a matching runner ref as `meshstack.runner_ref` to every building block module that uses a federated identity.

The machine that applies this module must reach the issuer URL, because the module reads the thumbprint there.

## Required permissions

The identity applying this needs `iam:CreateOpenIDConnectProvider`, `iam:GetOpenIDConnectProvider` and `iam:TagOpenIDConnectProvider` in the target account. A change of `audiences` also needs `iam:AddClientIDToOpenIDConnectProvider` and `iam:RemoveClientIDFromOpenIDConnectProvider`. A destroy needs `iam:DeleteOpenIDConnectProvider`.
