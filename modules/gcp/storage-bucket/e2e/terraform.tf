terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0.0"
    }
  }
}
