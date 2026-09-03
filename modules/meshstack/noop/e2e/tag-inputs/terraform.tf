terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
  }
}
