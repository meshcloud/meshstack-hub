terraform {
  required_version = ">= 1.12.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 3.0.0, < 4.0.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0, < 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}
