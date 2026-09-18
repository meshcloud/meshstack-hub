terraform {
  required_version = ">= 1.12.0" # const variables require OpenTofu >= 1.12

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.4" # meshstack_platforms data source + meshstack_tenant wait_for_completion
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0, < 4.0.0"
    }
  }
}
