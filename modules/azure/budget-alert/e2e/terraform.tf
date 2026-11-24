terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64.0, < 5.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.1, < 1.0.0"
    }
  }
}
