terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }
    forgejo = {
      source = "svalabs/forgejo"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }

    restapi = {
      source  = "Mastercard/restapi"
      version = "3.0.0"
    }
  }
}



