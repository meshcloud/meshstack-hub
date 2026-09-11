terraform {
  required_version = ">= 1.12.0" # const variables require OpenTofu >= 1.12

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.4" # meshstack_platforms data source + meshstack_tenant wait_for_completion
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.99.0, < 1.0.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 3.0.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0, < 4.0.0"
    }
  }
}
