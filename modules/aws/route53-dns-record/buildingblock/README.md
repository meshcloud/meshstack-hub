---
name: AWS Route53 DNS Record
supportedPlatforms:
  - aws
description: Provides AWS Route53 DNS records for mapping domain names to IP addresses or other values.
---

# AWS Route53 DNS Record

This Terraform module provisions AWS Route53 DNS records.

## Providers

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.77.0"
    }
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = var.allowed_account_ids  # Optional
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
| [aws_route53_record.record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_account_ids"></a> [allowed\_account\_ids](#input\_allowed\_account\_ids) | List of allowed AWS account IDs to prevent operations on the wrong account | `list(string)` | `null` | no |
| <a name="input_private_zone"></a> [private\_zone](#input\_private\_zone) | Set to true if the AWS Route 53 zone is a Private Hosted Zone. | `bool` | `false` | no |
| <a name="input_record"></a> [record](#input\_record) | DNS record value | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region | `string` | `"eu-central-1"` | no |
| <a name="input_sub"></a> [sub](#input\_sub) | DNS record name, excluding the `zone_name`. Leave empty to create apex records. | `string` | n/a | yes |
| <a name="input_ttl"></a> [ttl](#input\_ttl) | TTL of the record in seconds. | `string` | `"300"` | no |
| <a name="input_type"></a> [type](#input\_type) | DNS Record type | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | AWS Route53 zone name in which the record should be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_record_name"></a> [record\_name](#output\_record\_name) | The FQDN of the DNS record |
| <a name="output_record_type"></a> [record\_type](#output\_record\_type) | The type of the DNS record |
| <a name="output_record_value"></a> [record\_value](#output\_record\_value) | The value of the DNS record |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created DNS record |
<!-- END_TF_DOCS -->
