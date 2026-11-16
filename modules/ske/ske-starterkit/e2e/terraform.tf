terraform {
  required_version = ">= 1.11.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    external = {
      source = "hashicorp/external"
    }
  }
}
