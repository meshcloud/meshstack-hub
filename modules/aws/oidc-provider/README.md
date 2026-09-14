# meshStack OIDC Provider (shared)

Registers the meshStack building block runner's token issuer as an IAM OIDC provider so that AWS
backplanes in this account can trust it.

**Apply this once per AWS account that hosts building block backplanes.** AWS registers one OIDC
provider per issuer URL per account, so this cannot belong to an individual backplane: the second
backplane to try would fail with `EntityAlreadyExists`, and destroying whichever owned it would
break every other backplane in the account. Pass the `arn` output to each backplane's
`oidc_provider_arn` input.

See [the shared OIDC provider](../../../.agents/references/aws-backplane.md#the-shared-oidc-provider)
for the full rationale and for how to migrate an account whose provider is still owned by a
backplane's state.

## Usage

```hcl
provider "aws" {
  region = "eu-central-1"
}

module "meshstack_oidc_provider" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/oidc-provider?ref=main"

  workload_identity_federation = {
    issuer   = "https://<the runner's issuer>"
    audience = "<the runner's AWS audience>"
  }
}

# Then, per building block definition:
module "s3_bucket" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/s3_bucket?ref=main"

  aws_oidc_provider_arn = module.meshstack_oidc_provider.arn
  # ...
}
```

`issuer` and `audience` describe the runner. Every building block definition that runs on it
reports them as `status.workload_identity_federation.issuer` and
`status.workload_identity_federation.aws.audience`, so take them from any definition already
deployed on that runner, in whichever cloud. For a self-hosted runner pass that runner's values, and
pass its uuid as `building_block_runner_uuid` to every building block module that runs on it. The
thumbprint comes from the issuer's own TLS chain, so no other input is needed.

The issuer URL has to be reachable from wherever this runs, because the thumbprint is read from it.

## Required permissions

The identity applying this needs `iam:CreateOpenIDConnectProvider`, `iam:GetOpenIDConnectProvider`
and `iam:TagOpenIDConnectProvider` in the target account.
