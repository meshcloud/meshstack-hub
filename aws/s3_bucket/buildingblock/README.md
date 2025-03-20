---
name: AWS Building Block - S3 Bucket
card_description: |
  Building block module for adding an AWS S3 Bucket
---

# AWS S3 Bucket

This Terraform module provisions an AWS S3 bucket with basic configurations.

## How to Use

1. Define the required variables in your Terraform configuration.
2. Include this module in your Terraform code.
3. Apply the Terraform plan to provision the S3 bucket.
4. Use the outputs to integrate the bucket into your application or infrastructure.
5. Customize the bucket settings as needed.
6. Ensure proper IAM policies for access control.

## Requirements
- Terraform `>= 1.0`
- AWS Provider `~> 5.77.0`

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
  region = var.region
}


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.77.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | The name of the S3 bucket | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region | `string` | `"eu-central-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | n/a |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | n/a |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | n/a |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | n/a |
| <a name="output_bucket_uri"></a> [bucket\_uri](#output\_bucket\_uri) | n/a |
<!-- END_TF_DOCS -->