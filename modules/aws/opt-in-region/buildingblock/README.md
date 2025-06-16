---
name: Enable Opt-In Regions
supportedPlatforms:
  - aws
description: |
  The building block enables you to enable AWS regions that require explicit opt-in for your AWS account. This is particularly useful for managing access to newer AWS regions or regions with specific compliance requirements.
---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.77.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_account_region.region](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/resources/account_region) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | The ID of the target account where the opt-in region will be managed | `string` | n/a | yes |
| <a name="input_assume_role_arn"></a> [assume\_role\_arn](#input\_assume\_role\_arn) | The ARN of the role in the organization management account that the building block will assume to manage opt-in regions | `string` | n/a | yes |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the region is enabled | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | The region name to manage (e.g., ap-southeast-3, me-central-1, af-south-1) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_opt_status"></a> [opt\_status](#output\_opt\_status) | The region opt status |
| <a name="output_region"></a> [region](#output\_region) | The region name |
<!-- END_TF_DOCS -->