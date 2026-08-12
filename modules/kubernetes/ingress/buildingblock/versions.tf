terraform {
  required_version = ">= 1.12.0"

  required_providers {
    helm = {
      source = "hashicorp/helm"
      # The helm provider takes its cluster credentials as the `kubernetes = {}` attribute
      # starting with 3.0.0. Earlier versions expect a `kubernetes {}` block instead.
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38"
    }
  }
}
