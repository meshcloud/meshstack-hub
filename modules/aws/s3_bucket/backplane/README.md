---
name: AWS S3 Buildingblock Backplane
summary: |
  Deploys an IAM user with full S3 access
# optional: add additional metadata about implemented security controls
---

# AWS S3 Buildingblock Backplane

This will deploy an IAM user (or role only in case of using `workload_identity_federation`) with full S3 access (`s3:*`)

## Usage

```hcl
provider "aws" {
  region = "your-region" # e.g. eu-central-1
}

module "aws_s3_bucket_backplane" {
  source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/aws/s3_bucket/backplane"

  workload_identity_federation = {
    issuer   = "https://your-oidc-issuer"
    audience = "your-audience"
    subjects = [
      "system:serviceaccount:your-namespace:your-service-account-name",  # Exact match
      "system:serviceaccount:your-namespace:*",                          # Wildcard match
    ]
  } # Optional, if not provided, IAM access keys will be created instead
}

output "aws_s3_bucket_backplane" {
  value = module.aws_s3_bucket_backplane
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.buildingblock_s3_access_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_openid_connect_provider.buildingblock_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.buildingblock_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.assume_federated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.buildingblock_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.buildingblock_s3_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.buildingblock_s3_user_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.s3_full_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.workload_identity_federation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Set these options to add a trusted identity provider from meshStack to allow workload identity federation for authentication which can be used instead of access keys. Supports multiple subjects for migration paths and wildcard patterns (e.g., 'system:serviceaccount:namespace:*'). | <pre>object({<br>    issuer   = string,<br>    audience = string,<br>    subjects = list(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_credentials"></a> [credentials](#output\_credentials) | n/a |
| <a name="output_workload_identity_federation_role"></a> [workload\_identity\_federation\_role](#output\_workload\_identity\_federation\_role) | n/a |
<!-- END_TF_DOCS -->
