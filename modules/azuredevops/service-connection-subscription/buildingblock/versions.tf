terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.51.0, < 5.0.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.1.1, < 2.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.6.0, < 4.0.0"
    }
  }
}
