terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 1.3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.0"
    }

    restapi = {
      source  = "Mastercard/restapi"
      version = "3.0.0"
    }
  }
}
