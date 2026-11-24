terraform {
  required_version = ">= 1.11.0"

  required_providers {
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
