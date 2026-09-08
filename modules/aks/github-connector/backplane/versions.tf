terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.4.0, < 5.0.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.1.0, < 4.0.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.1, < 3.0.0"
    }
  }
}

