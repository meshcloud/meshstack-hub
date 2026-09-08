terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.6.0, < 7.0.0"
    }
  }
}

provider "github" {
  app_auth {}
}
