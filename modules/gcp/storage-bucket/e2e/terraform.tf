terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0"
    }
  }
}
