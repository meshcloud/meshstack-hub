terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = "~> 0.98.0"
    }
  }
}
