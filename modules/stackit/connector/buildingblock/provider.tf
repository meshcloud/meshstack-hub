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

provider "forgejo" {
  host      = var.forgejo_host
  api_token = var.forgejo_api_token
}
