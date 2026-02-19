terraform {
  required_version = ">= 1.3.0"
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "0.9.0"
    }
  }
}
