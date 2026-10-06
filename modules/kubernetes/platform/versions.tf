terraform {
  required_version = ">= 1.12.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0, < 4.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.12.0, < 6.0.0"
    }
  }
}
