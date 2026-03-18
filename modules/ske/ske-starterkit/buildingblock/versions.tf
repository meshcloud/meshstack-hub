
terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~>0.20.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }
}
