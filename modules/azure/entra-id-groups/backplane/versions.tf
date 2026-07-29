terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.65.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.8"
    }
  }
}
