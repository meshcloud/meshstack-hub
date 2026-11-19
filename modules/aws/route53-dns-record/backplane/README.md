# AWS Route53 DNS Record Backplane

This deploys the IAM role that the Route53 DNS Record building block assumes to manage records in the
hosted zones you list.

## Authentication

The building block authenticates with **workload identity federation** only. The backplane creates
an IAM role. With
`runner_identities`, AWS lets a run assume the role only if its token has the subject of this
definition.
The backplane returns the role ARN as `workload_identity_federation_role`. The module creates no
long-lived credential.

`runner_identities` has one entry per building block runner: the runner of the latest version and
each runner in `meshstack.additional_trusted_runner_refs`. Building blocks on older versions need the trusted
runners. Without them, AWS rejects the tokens of these building blocks after a new version uses
another runner. See
[Trusted runners](../../../../.agents/references/meshstack-integration.md#trusted-runners).

AWS allows **one OIDC provider per issuer URL per account**, so this backplane does not create one.
It looks up the provider of each issuer in `runner_identities`. Apply
[`modules/aws/oidc-provider`](../../oidc-provider) once per issuer and account before you plan this
backplane. See
[the shared OIDC provider](../../../../.agents/references/aws-backplane.md#the-shared-oidc-provider).

A caller can use this backplane without the `meshstack_integration.tf` of the module. This caller
passes one identity in `workload_identity_federation` and the ARN of its provider in
`oidc_provider_arn`.

## Required permissions

The platform engineer or CI principal applying this module needs `iam:*` on the role and the policy
it manages (`CreateRole`, `CreatePolicy`, `AttachRolePolicy` and their `Get`/`Delete` counterparts),
and `iam:ListOpenIDConnectProviders` and `iam:GetOpenIDConnectProvider` for the lookup of the OIDC
providers. `arn:aws:iam::aws:policy/IAMFullAccess` covers it.

## Usage

```hcl
provider "aws" {
  region = "eu-central-1" # or any other region
}

module "aws_route53_dns_record_backplane" {
  source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/aws/route53-dns-record/backplane"

  # List of Route53 hosted zone IDs that the building block can manage
  hosted_zone_ids = [
    "<hosted_zone_id_1>",
    "<hosted_zone_id_2>"
  ]

  name = "my-building-block"

  # One entry per runner. The integration passes the output of modules/meshstack/runner-identity,
  # see .agents/references/meshstack-integration.md#trusted-runners.
  runner_identities = [{
    issuer   = "https://your-oidc-issuer"
    audience = "your-audience"
    subject  = "system:serviceaccount:your-namespace:your-service-account-name"
  }]
}
```

The same role with `workload_identity_federation` and `oidc_provider_arn`:

```hcl
  # ARN of the account's shared meshStack OIDC provider, from modules/aws/oidc-provider.
  oidc_provider_arn = module.meshstack_oidc_provider.arn

  workload_identity_federation = {
    issuer   = "https://your-oidc-issuer"
    audience = "your-audience"
    subjects = ["system:serviceaccount:your-namespace:your-service-account-name"]
  }
```

## Migrating from the access key path

Earlier revisions created an IAM user and an `aws_iam_access_key` when `workload_identity_federation`
was left null. The backplane no longer creates them. If a deployment still uses the access key,
pass `runner_identities` or `workload_identity_federation`. The next apply then destroys the IAM
user and its key. A
deployment already on the federated path is unaffected: `moved` blocks carry its role and policy
attachment across the removed `count`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.32, < 7.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.buildingblock_route53_record_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.assume_federated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.buildingblock_route53_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.runner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.route53_record_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.workload_identity_federation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hosted_zone_ids"></a> [hosted\_zone\_ids](#input\_hosted\_zone\_ids) | List of Route53 hosted zone IDs that the building block can manage. Example: '<hosted\_zone\_id\_1>', '<hosted\_zone\_id\_2>'] | `list(string)` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the IAM OIDC provider for the issuer of `workload_identity_federation` in this AWS account.<br/>See .agents/references/aws-backplane.md#the-shared-oidc-provider | `string` | `null` | no |
| <a name="input_runner_identities"></a> [runner\_identities](#input\_runner\_identities) | AWS lets a run assume the role when its token matches one of these entries.<br/>Pass the output `identities` of modules/meshstack/runner-identity.<br/>The backplane skips an entry with a null subject, but still looks up the provider of its issuer.<br/>Create the IAM OIDC provider of each issuer in this AWS account first.<br/>See .agents/references/aws-backplane.md#the-shared-oidc-provider | <pre>list(object({<br/>    issuer   = string<br/>    audience = string<br/>    subject  = string<br/>  }))</pre> | `[]` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | One more entry like those in `runner_identities`, for a caller without modules/meshstack/runner-identity. Set `oidc_provider_arn` with it.<br/>Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*'). | <pre>object({<br/>    issuer   = string,<br/>    audience = string,<br/>    subjects = list(string)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_workload_identity_federation_role"></a> [workload\_identity\_federation\_role](#output\_workload\_identity\_federation\_role) | Workload identity federation role ARN |
<!-- END_TF_DOCS -->
