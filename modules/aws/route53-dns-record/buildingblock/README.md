---
name: AWS Route53 DNS Record
description: Provides AWS Route53 DNS records for mapping domain names to IP addresses or other values.
---

# AWS Route53 DNS Record

This Terraform module provisions AWS Route53 DNS records.

## Requirements
- Terraform `>= 1.3.0`
- AWS Provider `~> 5.0`

## Providers

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = var.allowed_account_ids  # Optional
}
```

<!-- BEGIN_TF_DOCS -->