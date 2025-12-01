terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.14.0"
    }
  }
}
