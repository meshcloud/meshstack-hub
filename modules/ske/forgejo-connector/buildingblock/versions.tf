terraform {
  required_providers {
    forgejo = {
      source = "svalabs/forgejo"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}




