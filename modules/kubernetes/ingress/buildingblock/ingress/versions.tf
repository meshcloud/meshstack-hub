terraform {
  required_version = ">= 1.12.0"

  # No `provider` block anywhere in this module, on purpose: a module that configures its own
  # provider cannot be called with `count`, `for_each` or `depends_on`, and cannot be driven by a
  # caller that already holds cluster credentials. The parent directory supplies both providers.
  required_providers {
    helm = {
      source = "hashicorp/helm"
      # The helm provider takes its cluster credentials as the `kubernetes = {}` attribute
      # starting with 3.0.0. Earlier versions expect a `kubernetes {}` block instead.
      version = ">= 3.0.0, < 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}
