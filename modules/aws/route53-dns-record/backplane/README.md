# AWS Route53 DNS Record Backplane

This deploys the IAM role that the Route53 DNS Record building block assumes to manage records in the
hosted zones you list.

## Authentication

The building block authenticates by **workload identity federation** — the only credential path this
backplane offers, so `workload_identity_federations` is required. The backplane creates an IAM role
whose trust policy accepts only the subjects of this building block definition and exports the role
ARN as `workload_identity_federation_role`. No long-lived credential exists anywhere in the module.

Pass one entry per runner the role trusts, for example the old and the new runner while a definition
moves from one to the other.

AWS allows **one OIDC provider per issuer URL per account**, so this backplane does not create one.
It looks up the provider of each issuer, so apply [`modules/aws/oidc-provider`](../../oidc-provider)
for each issuer first. See
[the shared OIDC provider](../../../../.agents/references/aws-backplane.md#the-shared-oidc-provider).

## Required permissions

The platform engineer or CI principal applying this module needs `iam:*` on the role and the policy
it manages (`CreateRole`, `CreatePolicy`, `AttachRolePolicy` and their `Get`/`Delete` counterparts),
plus `iam:ListOpenIDConnectProviders` and `iam:GetOpenIDConnectProvider` for the lookup.
`arn:aws:iam::aws:policy/IAMFullAccess` covers it.

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

  # meshStack resolves the subject per building block definition; see
  # .agents/references/meshstack-integration.md#runner-identity for how the integration wires this.
  workload_identity_federations = [{
    issuer   = "https://your-oidc-issuer"
    audience = "your-audience"
    subject  = "system:serviceaccount:your-namespace:your-service-account-name"
  }]
}
```

## Migrating from `workload_identity_federation`

Earlier revisions took one `workload_identity_federation` object with a `subjects` list, and an
`oidc_provider_arn`. Pass one entry per subject in `workload_identity_federations`, with that
subject as `subject`, and drop `oidc_provider_arn`. With one subject the trust policy of the role
stays the same, so the plan is empty.

## Migrating from the access key path

Earlier revisions created an IAM user and an `aws_iam_access_key` when `workload_identity_federation`
was left null. That path is gone. A deployment still on it must pass `workload_identity_federations`,
and the next apply destroys the IAM user and revokes its key — that is the intended migration. A
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
| [aws_iam_openid_connect_provider.trusted](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.route53_record_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.workload_identity_federation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hosted_zone_ids"></a> [hosted\_zone\_ids](#input\_hosted\_zone\_ids) | List of Route53 hosted zone IDs that the building block can manage. Example: '<hosted\_zone\_id\_1>', '<hosted\_zone\_id\_2>'] | `list(string)` | n/a | yes |
| <a name="input_workload_identity_federations"></a> [workload\_identity\_federations](#input\_workload\_identity\_federations) | meshStack identities the role trusts, one per building block runner. For more subjects of one<br/>issuer, pass one entry per subject. The backplane looks up this account's OIDC provider for each issuer.<br/>See .agents/references/aws-backplane.md#the-shared-oidc-provider | <pre>list(object({<br/>    issuer   = string<br/>    audience = string<br/>    subject  = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_workload_identity_federation_role"></a> [workload\_identity\_federation\_role](#output\_workload\_identity\_federation\_role) | Workload identity federation role ARN |
<!-- END_TF_DOCS -->
