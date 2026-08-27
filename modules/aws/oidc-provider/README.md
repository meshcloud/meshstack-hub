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

provider "meshstack" {}

module "meshstack_oidc_provider" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/oidc-provider?ref=main"
}

# Then, per building block definition:
module "s3_bucket" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/s3_bucket?ref=main"

  aws_oidc_provider_arn = module.meshstack_oidc_provider.arn
  # ...
}
```

The issuer, audience and thumbprint are read from `data.meshstack_integrations`, so this module
takes no inputs — it needs an `aws` provider pointed at the account and a configured `meshstack`
provider.

## Required permissions

The identity applying this needs `iam:CreateOpenIDConnectProvider`, `iam:GetOpenIDConnectProvider`
and `iam:TagOpenIDConnectProvider` in the target account.
