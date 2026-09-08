terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64, < 5.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.8, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.8, < 4.0.0"
    }
  }
}

