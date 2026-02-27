terraform {
  required_version = ">= 1.3.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.0"
    }
    gitea = {
      source  = "go-gitea/gitea"
      version = "~> 0.7.0"
    }
  }
}
