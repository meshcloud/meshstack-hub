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
  host      = local.forgejo.host
  api_token = local.forgejo.api_token
}
