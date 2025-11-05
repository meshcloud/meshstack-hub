terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.36.0"
      configuration_aliases = [azurerm, azurerm.hub]
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}
