terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.1.1, < 2.0.0"
    }
  }
}

provider "azuredevops" {
  org_service_url       = "https://dev.azure.com/${var.test_context.fixtures.azuredevops.organization}"
  personal_access_token = var.azuredevops_personal_access_token
}
