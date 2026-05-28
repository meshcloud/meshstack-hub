terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.64.0"
      configuration_aliases = [azurerm, azurerm.hub]
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.11.1"
    }
  }
}
