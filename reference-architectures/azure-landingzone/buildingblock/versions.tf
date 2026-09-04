terraform {
  required_version = ">= 1.12.0" # const variables require OpenTofu >= 1.12 / Terraform >= 1.15

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.8"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}
