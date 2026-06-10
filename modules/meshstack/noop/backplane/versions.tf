terraform {
  required_version = ">= 1.12.0"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.21.0"
    }
  }
}
