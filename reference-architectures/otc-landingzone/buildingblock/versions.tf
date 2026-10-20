terraform {
  required_version = ">= 1.12.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0, < 4.0.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.26.4" # meshstack_platform_type
    }
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.37.0, < 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0, < 4.0.0"
    }
  }
}
