terraform {
  required_version = ">= 1.11.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.4"
    }
  }
}
