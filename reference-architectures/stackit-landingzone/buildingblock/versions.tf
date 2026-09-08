terraform {
  required_version = ">= 1.12.0" # const variables require OpenTofu >= 1.12 / Terraform >= 1.15

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.99.0, < 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0, < 4.0.0"
    }
  }
}
