terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.65.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.3, < 4.0.0"
    }
  }
}
