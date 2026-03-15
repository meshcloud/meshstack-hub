terraform {
  required_version = ">= 1.4.0"

  required_providers {
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 1.3.0"
    }
  }
}
