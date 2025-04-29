terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "5.42.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.116.0"
    }
  }
}

provider "github" {
  owner = var.github_org
  app_auth {} # When using `GITHUB_APP_XXX` environment variables
}
