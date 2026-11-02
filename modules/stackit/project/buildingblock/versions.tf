terraform {
  required_version = ">= 1.11.0"
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0, < 3.0.0"
    }
  }
}
