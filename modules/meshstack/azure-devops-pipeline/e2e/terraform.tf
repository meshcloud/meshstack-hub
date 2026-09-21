terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    azuredevops = {
      source = "microsoft/azuredevops"
    }
  }
}

provider "azuredevops" {
  org_service_url       = "https://dev.azure.com/${var.test_context.fixtures.azuredevops.organization}"
  personal_access_token = var.azuredevops_personal_access_token
}
