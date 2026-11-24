terraform {
  required_version = ">= 1.12.0"

  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    stackit = {
      source = "stackitcloud/stackit"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
