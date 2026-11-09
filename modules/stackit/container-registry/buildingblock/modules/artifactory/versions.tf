terraform {
  required_version = ">= 1.11.0"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}
