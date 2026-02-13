---
name: AWS Route53 DNS Alias Record
supportedPlatforms:
  - aws
description: Provides AWS Route53 DNS alias records
---

# AWS Route53 DNS Alias Record

This Terraform module provisions AWS Route53 DNS alias records.

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


## Backend configuration
Here you can find an example of how to create a backend.tf file on this [Wiki Page](https://github.com/meshcloud/building-blocks/wiki/%5BUser-Guide%5D-Setting-up-the-Backend-for-terraform-state#how-to-configure-backendtf-file-for-these-providers)

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
| <a name="input_alias_evaluate_target_health"></a> [alias\_evaluate\_target\_health](#input\_alias\_evaluate\_target\_health) | When set to true, an alias resource record set inherits the health of the referenced AWS resource, such as an ELB load balancer or another resource record set in the hosted zone. | `bool` | `false` | no |
| <a name="input_alias_name"></a> [alias\_name](#input\_alias\_name) | Alias target DNS name. | `string` | n/a | yes |
| <a name="input_alias_zone_id"></a> [alias\_zone\_id](#input\_alias\_zone\_id) | AWS Route53 hosted zone id for the alias target. Note: These can be magic constants, see https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-aliastarget.html | `string` | n/a | yes |
| <a name="input_allowed_account_ids"></a> [allowed\_account\_ids](#input\_allowed\_account\_ids) | List of allowed AWS account IDs to prevent operations on the wrong account | `list(string)` | `null` | no |
| <a name="input_private_zone"></a> [private\_zone](#input\_private\_zone) | Set to true if the AWS Route 53 zone is a Private Hosted Zone. | `bool` | `false` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region | `string` | `"eu-central-1"` | no |
| <a name="input_sub"></a> [sub](#input\_sub) | DNS record name, excluding the `zone_name`. Use the value '@' to create an apex record. | `string` | n/a | yes |
| <a name="input_type"></a> [type](#input\_type) | n/a | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | AWS Route53 zone name in which the record should be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alias_target"></a> [alias\_target](#output\_alias\_target) | The alias target |
| <a name="output_record_name"></a> [record\_name](#output\_record\_name) | The FQDN of the DNS record |
| <a name="output_record_type"></a> [record\_type](#output\_record\_type) | The type of the DNS record |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created DNS alias record |
<!-- END_TF_DOCS -->