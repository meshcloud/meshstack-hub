terraform {
  required_version = ">= 1.3.0"
  required_providers {
    btp = {
      source  = "sap/btp"
      version = "~> 1.8.0"
    }
  }
}
