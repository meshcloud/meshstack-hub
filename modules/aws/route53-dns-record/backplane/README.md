# AWS Route53 DNS Record Backplane

This will deploy an IAM user (or role only in case of using `workload_identity_federation`) with Route53 access for managing DNS records.

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

  workload_identity_federation = {
    issuer   = "https://your-oidc-issuer"
    audience = "your-audience"
    subjects = [
      "system:serviceaccount:your-namespace:your-service-account-name",  # Exact match
      "system:serviceaccount:your-namespace:*",                          # Wildcard match
    ]
  } # Optional, if not provided, IAM access keys will be created instead
}

output "aws_route53_dns_record_backplane" {
  value = module.aws_route53_dns_record_backplane
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.32 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.buildingblock_route53_record_access_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_openid_connect_provider.buildingblock_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.buildingblock_route53_record_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.assume_federated_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.buildingblock_route53_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.buildingblock_route53_record_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.buildingblock_route53_record_user_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.route53_record_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.workload_identity_federation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hosted_zone_ids"></a> [hosted\_zone\_ids](#input\_hosted\_zone\_ids) | List of Route53 hosted zone IDs that the building block can manage. Example: '<hosted\_zone\_id\_1>', '<hosted\_zone\_id\_2>'] | `list(string)` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Set these options to add a trusted identity provider from meshStack to allow workload identity federation for authentication which can be used instead of access keys. Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*'). | <pre>object({<br>    issuer   = string,<br>    audience = string,<br>    subjects = list(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_credentials"></a> [credentials](#output\_credentials) | n/a |
| <a name="output_workload_identity_federation_role"></a> [workload\_identity\_federation\_role](#output\_workload\_identity\_federation\_role) | n/a |
<!-- END_TF_DOCS -->
