terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64.0, < 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.1, < 3.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0, < 4.0.0"
    }
  }
}
