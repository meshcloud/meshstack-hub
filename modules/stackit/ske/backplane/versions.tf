terraform {
  required_version = ">= 1.3.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.68.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
