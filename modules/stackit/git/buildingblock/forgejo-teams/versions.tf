terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0, < 4.0.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}
