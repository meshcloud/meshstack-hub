terraform {
  required_version = ">= 1.3.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
