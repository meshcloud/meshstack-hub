---
name: AWS Route53 DNS Alias Record
description: Provides AWS Route53 DNS alias records
---

# AWS Route53 DNS Alias Record

This Terraform module provisions AWS Route53 DNS alias records.

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

## Backend configuration
Here you can find an example of how to create a backend.tf file on this [Wiki Page](https://github.com/meshcloud/building-blocks/wiki/%5BUser-Guide%5D-Setting-up-the-Backend-for-terraform-state#how-to-configure-backendtf-file-for-these-providers)