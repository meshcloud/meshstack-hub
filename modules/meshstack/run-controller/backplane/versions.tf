terraform {
  required_version = ">= 1.12.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0, < 4.0.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12, < 1.0.0"
    }
  }
}
