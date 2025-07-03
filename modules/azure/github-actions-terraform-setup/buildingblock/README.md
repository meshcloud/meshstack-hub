---
name: Azure GitHub Actions Terraform Setup
supportedPlatforms:
  - azure
description: |
  Deploy directly to Azure using GitHub Actions and Terraform brought to you by meshStack
---

# Azure Key Vault

This Terraform module provisions an Azure Key Vault along with necessary role assignments.


## Requirements
- Terraform `>= 1.0`
- AzureRM Provider `>= 4.18.0`

## Providers

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.18.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
