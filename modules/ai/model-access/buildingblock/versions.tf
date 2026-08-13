terraform {
  required_version = ">= 1.12.0"

  required_providers {
    litellm = {
      source = "ncecere/litellm"
      # Exact pin, a deliberate exception to the hub rule that provider constraints use '>='.
      # ncecere/litellm is a community provider with a single maintainer, and it has changed
      # resource behaviour inside a minor release before: v1.2.0 replaced the id of litellm_key
      # with a hash of the key. LiteLLM returns a virtual key once and never again, so a provider
      # change that recreates the key takes the credential away from a running application. The
      # version is therefore pinned here and raised deliberately after a review of the changelog.
      version = "= 2.0.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38"
    }

    helm = {
      source = "hashicorp/helm"
      # The helm provider takes its cluster credentials as the `kubernetes = {}` attribute
      # starting with 3.0.0. Earlier versions expect a `kubernetes {}` block instead.
      version = ">= 3.0.0"
    }

    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }

    random = {
      source = "hashicorp/random"
      # random_bytes arrived in 3.5.0. Its `hex` and `base64` attributes are marked sensitive,
      # unlike those of random_id, which keeps the generated Langfuse secrets out of the plan.
      version = ">= 3.5.0"
    }
  }
}
