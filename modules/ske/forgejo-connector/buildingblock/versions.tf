terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0, < 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36.0, < 3.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.8.0, < 4.0.0"
    }

    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 3.0.0, < 4.0.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.12.0, < 6.0.0"
    }
  }
}
