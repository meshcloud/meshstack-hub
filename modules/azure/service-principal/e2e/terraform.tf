terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0.0, < 6.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.8, < 4.0.0"
    }
  }
}
