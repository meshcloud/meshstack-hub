terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.22.0"
    }
  }
}
