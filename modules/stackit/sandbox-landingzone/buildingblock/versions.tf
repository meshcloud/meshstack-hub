terraform {
  required_version = ">= 1.12.0" # const variables require OpenTofu >= 1.12 / Terraform >= 1.15

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.22.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.99.0"
    }
  }
}
