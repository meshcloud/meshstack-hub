terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.25.2"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.82.0, < 1.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.12.0, < 6.0.0"
    }
  }
}
