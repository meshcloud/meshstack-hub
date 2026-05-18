terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}
