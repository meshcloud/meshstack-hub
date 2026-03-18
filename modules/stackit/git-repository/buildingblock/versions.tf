terraform {
  required_version = ">= 1.4.0"

  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 1.3.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "3.0.0"
    }
  }
}
