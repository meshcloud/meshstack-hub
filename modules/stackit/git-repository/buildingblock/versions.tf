terraform {
  required_version = ">= 1.4.0"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "3.0.0"
    }
  }
}
