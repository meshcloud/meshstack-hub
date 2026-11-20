terraform {
  required_version = ">= 1.12.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = ">= 2.0.0, < 3.0.0"
    }
  }
}
