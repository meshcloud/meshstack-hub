---
name: AWS S3 Buildingblock Backplane
summary: |
  Deploys the federated IAM role the S3 building block assumes, with full S3 access
# optional: add additional metadata about implemented security controls
---

# AWS S3 Buildingblock Backplane

This deploys the IAM role that the S3 building block assumes, with full S3 access (`s3:*`).

## Authentication

The building block authenticates by **workload identity federation** — the only credential path this
backplane offers, so `workload_identity_federation` is required. The backplane registers the
meshStack issuer as an OIDC provider, creates an IAM role whose trust policy accepts only the
subjects of this building block definition, and exports the role ARN as
`workload_identity_federation_role`. No long-lived credential exists anywhere in the module.

AWS allows **one OIDC provider per issuer URL per account**. A second backplane in the same account
must therefore set `create_oidc_provider = false` and reuse the existing one — otherwise its apply
fails with `EntityAlreadyExists`.

## Required permissions

The platform engineer or CI principal applying this module needs `iam:*` on the OIDC provider, the
role and the policy it manages (`CreateOpenIDConnectProvider`, `CreateRole`, `CreatePolicy`,
`AttachRolePolicy` and their `Get`/`Delete` counterparts). `arn:aws:iam::aws:policy/IAMFullAccess`
covers it.

## Usage

```hcl
provider "aws" {
  region = "eu-central-1" # or any other region
}

module "aws_s3_bucket_backplane" {
  source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/aws/s3_bucket/backplane"

  workload_identity_federation = {
    issuer   = "https://your-oidc-issuer"
    audience = "your-audience"
    subjects = [
      "system:serviceaccount:your-namespace:your-service-account-name", # Exact match
      "system:serviceaccount:your-namespace:*",                         # Wildcard match
    ]
  }

  # Set to false when another backplane already created the meshStack OIDC provider in this account.
  create_oidc_provider = true
}
```

## Migrating from the access key path

Earlier revisions created an IAM user and an `aws_iam_access_key` when `workload_identity_federation`
was left null. That path is gone. A deployment still on it must pass `workload_identity_federation`,
and the next apply destroys the IAM user and revokes its key — that is the intended migration. A
deployment already on the federated path is unaffected: `moved` blocks carry its role and policy
attachment across the removed `count`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.buildingblock_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.buildingblock_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.assume_federated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.buildingblock_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.buildingblock_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.s3_full_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.workload_identity_federation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_oidc_provider"></a> [create\_oidc\_provider](#input\_create\_oidc\_provider) | Set to false if the OIDC provider for the meshStack issuer already exists in this AWS account (e.g., created by another backplane). The existing provider will be looked up by URL instead of created. | `bool` | `true` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Trusted identity provider from meshStack that the building block runner federates into.<br/>Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*'). | <pre>object({<br/>    issuer   = string,<br/>    audience = string,<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_workload_identity_federation_role"></a> [workload\_identity\_federation\_role](#output\_workload\_identity\_federation\_role) | Workload identity federation role ARN |
<!-- END_TF_DOCS -->
