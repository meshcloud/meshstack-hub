terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0.0"
    }
  }
}
