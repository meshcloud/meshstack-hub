# AWS Route53 DNS Alias Record Backplane

This deploys the IAM role that the Route53 DNS Alias Record building block assumes to manage alias
records in the hosted zones you list.

## Authentication

The building block authenticates by **workload identity federation** — the only credential path this
backplane offers. The backplane creates an IAM role whose trust policy accepts only the subjects of
this building block definition and exports the role ARN as `workload_identity_federation_role`. No
long-lived credential exists anywhere in the module.

The role trusts one identity per building block runner, passed in `runner_identities`. A building
block keeps running on the definition version it was created with. So while a definition moves to
another runner, the list holds the new runner and the old one, and building blocks on older versions
can still sign in. The integration fills the list from `meshstack.trusted_runner_refs`, see
[Trusted runners](../../../../.agents/references/meshstack-integration.md#trusted-runners). With one
runner, the trust policy is the same as before the list existed.

AWS allows **one OIDC provider per issuer URL per account**, so this backplane does not create one.
It looks up the provider of each issuer in `runner_identities`. Apply
[`modules/aws/oidc-provider`](../../oidc-provider) once per issuer and account before you plan this
backplane. See
[the shared OIDC provider](../../../../.agents/references/aws-backplane.md#the-shared-oidc-provider).

A caller that uses this backplane without the integration can instead pass one identity in
`workload_identity_federation`, together with the ARN of its provider in `oidc_provider_arn`.

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

module "aws_route53_dns_alias_record_backplane" {
  source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/aws/route53-dns-alias-record/backplane"

  # List of Route53 hosted zone IDs that the building block can manage
  hosted_zone_ids = [
    "<hosted_zone_id_1>",
    "<hosted_zone_id_2>"
  ]

  # One identity per runner. meshStack resolves the subject per building block definition; see
  # .agents/references/meshstack-integration.md#trusted-runners for how the integration wires this.
  runner_identities = [{
    issuer   = "https://your-oidc-issuer"
    audience = "your-audience"
    subject  = "system:serviceaccount:your-namespace:your-service-account-name"
  }]
}
```

The old form still works and gives the same role:

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
was left null. That path is gone. A deployment still on it must pass `runner_identities` or
`workload_identity_federation`, and the next apply destroys the IAM user and revokes its key — that is the intended migration. A
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
| [aws_iam_policy.buildingblock_route53_alias_record_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.assume_federated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.buildingblock_route53_alias_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.runner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.route53_alias_record_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.workload_identity_federation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hosted_zone_ids"></a> [hosted\_zone\_ids](#input\_hosted\_zone\_ids) | List of Route53 hosted zone IDs that the building block can manage. Example: ['<hosted\_zone\_id\_1>', '<hosted\_zone\_id\_2>'] | `list(string)` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the IAM OIDC provider for the issuer of `workload_identity_federation` in this AWS account.<br/>See .agents/references/aws-backplane.md#the-shared-oidc-provider | `string` | `null` | no |
| <a name="input_runner_identities"></a> [runner\_identities](#input\_runner\_identities) | The meshStack identities the role trusts, one per building block runner: the output `identities` of<br/>modules/meshstack/runner-identity. An entry with a null subject is skipped.<br/>The backplane looks up the IAM OIDC provider of each issuer in this AWS account.<br/>See .agents/references/aws-backplane.md#the-shared-oidc-provider | <pre>list(object({<br/>    issuer   = string<br/>    audience = string<br/>    subject  = string<br/>  }))</pre> | `[]` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | One more identity the role trusts, for a caller that does not use `runner_identities`. It needs `oidc_provider_arn`.<br/>Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*'). | <pre>object({<br/>    issuer   = string,<br/>    audience = string,<br/>    subjects = list(string)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_workload_identity_federation_role"></a> [workload\_identity\_federation\_role](#output\_workload\_identity\_federation\_role) | Workload identity federation role ARN |
<!-- END_TF_DOCS -->
