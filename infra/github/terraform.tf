terraform {
  required_version = ">= 1.0"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0, < 5.0.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.5.0, < 7.0.0"
    }
  }
}

provider "github" {
  owner = "meshcloud"
}
