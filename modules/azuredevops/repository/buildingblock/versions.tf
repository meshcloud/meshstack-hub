terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.51.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.1.1"
    }
  }
}
