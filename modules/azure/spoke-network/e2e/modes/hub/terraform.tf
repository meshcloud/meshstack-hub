terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.37.0, < 5.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.1, < 1.0.0"
    }
  }
}
