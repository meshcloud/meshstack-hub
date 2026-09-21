terraform {
  required_version = ">= 1.11.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.1.1, < 2.0.0"
    }
  }
}
