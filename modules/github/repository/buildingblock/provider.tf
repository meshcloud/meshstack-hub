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
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file
  }
}
