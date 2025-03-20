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

