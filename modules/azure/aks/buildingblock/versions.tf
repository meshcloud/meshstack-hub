terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.36.0"
      configuration_aliases = [azurerm, azurerm.hub]
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.4.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.11.1"
    }
  }
}
