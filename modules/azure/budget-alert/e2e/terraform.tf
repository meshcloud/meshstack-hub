terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.1, < 1.0.0"
    }
  }
}
