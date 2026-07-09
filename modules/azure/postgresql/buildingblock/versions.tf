terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.8"
    }
  }
}
