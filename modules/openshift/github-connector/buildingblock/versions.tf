terraform {
  required_version = ">= 1.12.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.5.0, < 7.0.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.1, < 3.0.0"
    }
  }
}
